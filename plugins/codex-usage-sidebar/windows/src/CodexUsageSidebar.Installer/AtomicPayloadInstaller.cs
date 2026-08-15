using System.Text.Json;
using System.Security.Cryptography;
using System.Globalization;

namespace CodexUsageSidebar.Installer;

public sealed class AtomicPayloadInstaller
{
    private const string ManifestName = "windows-payload.json";
    private const string OfficialCodexReleasePrefix = "https://github.com/openai/codex/releases/download/";
    private static readonly TimeSpan PreviousPayloadMoveRetryWindow = TimeSpan.FromSeconds(10);
    private static readonly TimeSpan PreviousPayloadMoveRetryDelay = TimeSpan.FromMilliseconds(100);
    private static readonly HashSet<string> RequiredFiles = new(StringComparer.OrdinalIgnoreCase)
    {
        "CodexUsageSidebar.Windows.exe",
        "CodexUsageSidebar.Control.exe",
        "codex.exe",
        "selectors.json",
    };

    private readonly TrustedPayloadIdentity trustedIdentity;
    private readonly IBackupCleaner backupCleaner;
    private readonly IPayloadStageValidator stageValidator;
    private readonly bool reportSafeStages;

    public AtomicPayloadInstaller(
        TrustedPayloadIdentity trustedIdentity,
        IBackupCleaner? backupCleaner = null,
        IPayloadStageValidator? stageValidator = null,
        bool reportSafeStages = false)
    {
        ValidateTrustedIdentity(trustedIdentity);
        this.trustedIdentity = trustedIdentity;
        this.backupCleaner = backupCleaner ?? new BackupCleaner();
        this.stageValidator = stageValidator ?? new PayloadStageValidator();
        this.reportSafeStages = reportSafeStages;
    }

    public void Install(string source, string destination)
    {
        var sourcePath = Path.GetFullPath(source);
        var destinationPath = Path.GetFullPath(destination);
        if (!Directory.Exists(sourcePath))
        {
            throw new DirectoryNotFoundException(sourcePath);
        }
        if (IsSameOrDescendant(destinationPath, sourcePath))
        {
            throw new InvalidDataException("The destination cannot be inside the source payload.");
        }

        ValidateNoLinks(sourcePath);
        if (OperatingSystem.IsWindows())
        {
            ValidateExistingAncestors(Path.GetDirectoryName(destinationPath)!);
        }
        var parent = Path.GetDirectoryName(destinationPath)
            ?? throw new InvalidDataException("The destination must have a parent directory.");
        Directory.CreateDirectory(parent);
        var operationId = Guid.NewGuid().ToString("N");
        var temporary = Path.Combine(parent, ".cus-stage-" + operationId);
        var backup = Path.Combine(parent, ".cus-backup-" + operationId);
        var lockPath = Path.Combine(parent, ".cus-install.lock");

        var movedPrevious = false;
        var activated = false;
        try
        {
            FileStream operationLock;
            try
            {
                operationLock = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            }
            catch (Exception error) when (reportSafeStages)
            {
                throw new InstallerSafeStageException("payload-install-lock", error);
            }
            using (operationLock)
            {
                RunStage("payload-copy", () => CopyDirectory(sourcePath, temporary));
                RunStage("payload-validation", () => stageValidator.Validate(temporary, trustedIdentity));
                if (Directory.Exists(destinationPath))
                {
                    RunStage("previous-payload-move", () => MovePreviousPayload(destinationPath, backup));
                    movedPrevious = true;
                }
                RunStage("new-payload-move", () => Directory.Move(temporary, destinationPath));
                activated = true;
            }
        }
        catch
        {
            if (activated && Directory.Exists(destinationPath))
            {
                Directory.Delete(destinationPath, recursive: true);
            }
            if (movedPrevious && Directory.Exists(backup))
            {
                Directory.Move(backup, destinationPath);
            }
            throw;
        }
        finally
        {
            TryDeleteDirectory(temporary);
            TryDeleteFile(lockPath);
        }
        if (activated && movedPrevious && Directory.Exists(backup))
        {
            backupCleaner.TryDelete(backup);
        }
    }

    private void RunStage(string stage, Action action)
    {
        try
        {
            action();
        }
        catch (InstallerSafeStageException)
        {
            throw;
        }
        catch (Exception error) when (reportSafeStages)
        {
            throw new InstallerSafeStageException(stage, error);
        }
    }

    private static void MovePreviousPayload(string destinationPath, string backup)
    {
        var deadline = DateTimeOffset.UtcNow + PreviousPayloadMoveRetryWindow;
        while (true)
        {
            try
            {
                Directory.Move(destinationPath, backup);
                return;
            }
            catch (Exception error) when (IsRetryablePreviousPayloadMove(error)
                && DateTimeOffset.UtcNow < deadline)
            {
                Thread.Sleep(PreviousPayloadMoveRetryDelay);
            }
        }
    }

    private static bool IsRetryablePreviousPayloadMove(Exception error) =>
        error is IOException or UnauthorizedAccessException;

    internal static void ValidateManifest(string source, TrustedPayloadIdentity trustedIdentity)
    {
        var manifestPath = Path.Combine(source, ManifestName);
        if (!File.Exists(manifestPath))
        {
            throw new InvalidDataException($"Missing {ManifestName}.");
        }
        try
        {
            if (trustedIdentity.PayloadManifestSha256 is { } trustedManifestDigest)
            {
                using var manifestStream = File.OpenRead(manifestPath);
                var actualManifestDigest = Convert.ToHexString(SHA256.HashData(manifestStream)).ToLowerInvariant();
                if (!string.Equals(actualManifestDigest, trustedManifestDigest, StringComparison.Ordinal))
                {
                    throw new InvalidDataException("The Windows payload manifest digest is not trusted by this installer.");
                }
            }
            using var document = JsonDocument.Parse(File.ReadAllText(manifestPath));
            var root = document.RootElement;
            if (!root.TryGetProperty("schemaVersion", out var schemaVersion)
                || schemaVersion.ValueKind != JsonValueKind.Number
                || schemaVersion.GetInt32() != 1)
            {
                throw new InvalidDataException("The Windows payload schema is not supported.");
            }
            if (!root.TryGetProperty("version", out var version)
                || version.ValueKind != JsonValueKind.String
                || !string.Equals(version.GetString(), trustedIdentity.Version, StringComparison.Ordinal))
            {
                throw new InvalidDataException("The Windows payload version does not match the installer.");
            }
            if (!root.TryGetProperty("architecture", out var architecture)
                || architecture.ValueKind != JsonValueKind.String
                || architecture.GetString() != "x64")
            {
                throw new InvalidDataException("The Windows beta payload must declare the x64 architecture.");
            }
            if (!root.TryGetProperty("sourceCommit", out var sourceCommit)
                || sourceCommit.ValueKind != JsonValueKind.String
                || !string.Equals(sourceCommit.GetString(), trustedIdentity.SourceCommit, StringComparison.Ordinal))
            {
                throw new InvalidDataException("The Windows payload source commit is not trusted by this installer.");
            }
            var expectedPolicy = trustedIdentity.Policy switch
            {
                PayloadManifestPolicy.DeviceTest => (Status: "device-test", Validated: false, Publishable: false),
                PayloadManifestPolicy.PublishedRelease => (Status: "release", Validated: true, Publishable: true),
                _ => throw new InvalidDataException("The trusted Windows payload policy is unsupported."),
            };
            var isQuickPrerelease = trustedIdentity.Policy == PayloadManifestPolicy.PublishedRelease
                && root.TryGetProperty("validationProfile", out var validationProfile)
                && validationProfile.ValueKind == JsonValueKind.String
                && validationProfile.GetString() == "quick-prerelease";
            if (trustedIdentity.Policy == PayloadManifestPolicy.DeviceTest
                && (root.TryGetProperty("validationProfile", out _)
                    || root.TryGetProperty("quickPrereleaseValidation", out _)
                    || root.TryGetProperty("realDeviceValidation", out _)))
            {
                throw new InvalidDataException(
                    "A device-test Windows payload cannot carry release validation metadata.");
            }
            var expectedValidated = isQuickPrerelease ? false : expectedPolicy.Validated;
            if (!root.TryGetProperty("status", out var status)
                || status.ValueKind != JsonValueKind.String
                || status.GetString() != expectedPolicy.Status
                || !root.TryGetProperty("realDeviceValidated", out var realDeviceValidated)
                || !TryReadBoolean(realDeviceValidated, out var actualValidated)
                || actualValidated != expectedValidated
                || !root.TryGetProperty("publishableInstaller", out var publishableInstaller)
                || !TryReadBoolean(publishableInstaller, out var actualPublishable)
                || actualPublishable != expectedPolicy.Publishable)
            {
                throw new InvalidDataException("The Windows payload publication state does not match this installer.");
            }
            if (!root.TryGetProperty("codexRuntime", out var codexRuntime)
                || codexRuntime.ValueKind != JsonValueKind.Object
                || !codexRuntime.TryGetProperty("source", out var runtimeSource)
                || runtimeSource.ValueKind != JsonValueKind.String
                || !string.Equals(runtimeSource.GetString(), trustedIdentity.CodexRuntimeSource, StringComparison.Ordinal)
                || !codexRuntime.TryGetProperty("sha256", out var runtimeDigest)
                || runtimeDigest.ValueKind != JsonValueKind.String
                || !string.Equals(runtimeDigest.GetString(), trustedIdentity.CodexRuntimeSha256, StringComparison.Ordinal))
            {
                throw new InvalidDataException("The Codex runtime provenance is not trusted by this installer.");
            }
            if (!root.TryGetProperty("files", out var files) || files.ValueKind != JsonValueKind.Object)
            {
                throw new InvalidDataException("The Windows payload manifest must contain file digests.");
            }

            var declared = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var property in files.EnumerateObject())
            {
                var relative = property.Name.Replace('/', Path.DirectorySeparatorChar);
                if (Path.IsPathRooted(relative) || relative.Split(Path.DirectorySeparatorChar).Any(x => x is "" or "." or ".."))
                {
                    throw new InvalidDataException("The Windows payload manifest contains an unsafe file path.");
                }
                var digest = property.Value.ValueKind == JsonValueKind.String ? property.Value.GetString() : null;
                if (digest is null || digest.Length != 64 || !digest.All(Uri.IsHexDigit))
                {
                    throw new InvalidDataException("The Windows payload manifest contains an invalid SHA-256 digest.");
                }
                var filePath = Path.GetFullPath(Path.Combine(source, relative));
                if (!IsSameOrDescendant(filePath, source) || !File.Exists(filePath))
                {
                    throw new InvalidDataException("A declared Windows payload file is missing or outside the payload.");
                }
                using var stream = File.OpenRead(filePath);
                var actual = Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
                if (!string.Equals(actual, digest, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidDataException($"Windows payload digest mismatch: {property.Name}");
                }
                declared.Add(Path.GetRelativePath(source, filePath));
            }

            if (!RequiredFiles.IsSubsetOf(declared)
                || !files.TryGetProperty("codex.exe", out var declaredRuntimeDigest)
                || declaredRuntimeDigest.ValueKind != JsonValueKind.String
                || !string.Equals(
                    declaredRuntimeDigest.GetString(),
                    trustedIdentity.CodexRuntimeSha256,
                    StringComparison.Ordinal))
            {
                throw new InvalidDataException("The Windows payload is incomplete or its Codex runtime binding is invalid.");
            }
            if (trustedIdentity.Policy == PayloadManifestPolicy.PublishedRelease)
            {
                const string validationFile = "windows-validation.json";
                var validationProperty = isQuickPrerelease
                    ? "quickPrereleaseValidation"
                    : "realDeviceValidation";
                if (!declared.Contains(validationFile)
                    || !files.TryGetProperty(validationFile, out var declaredValidationDigest)
                    || declaredValidationDigest.ValueKind != JsonValueKind.String
                    || !root.TryGetProperty(validationProperty, out var validation)
                    || validation.ValueKind != JsonValueKind.Object
                    || !validation.TryGetProperty("sha256", out var trustedValidationDigest)
                    || trustedValidationDigest.ValueKind != JsonValueKind.String
                    || !string.Equals(
                        trustedValidationDigest.GetString(),
                        declaredValidationDigest.GetString(),
                        StringComparison.Ordinal))
                {
                    throw new InvalidDataException(
                        "A published Windows payload must bind its exact validation evidence.");
                }
                if (isQuickPrerelease)
                {
                    if (root.TryGetProperty("realDeviceValidation", out _)
                        || !JsonPropertyNamesEqual(
                            validation,
                            ["sha256", "windowsBuild", "codexFileBuild", "completedAt", "smoke"])
                        || !validation.TryGetProperty("windowsBuild", out var windowsBuild)
                        || windowsBuild.ValueKind != JsonValueKind.Number
                        || !windowsBuild.TryGetInt32(out var windowsBuildValue)
                        || windowsBuildValue < 22_000
                        || !validation.TryGetProperty("codexFileBuild", out var codexFileBuild)
                        || codexFileBuild.ValueKind != JsonValueKind.String
                        || !validation.TryGetProperty("completedAt", out var completedAt)
                        || completedAt.ValueKind != JsonValueKind.String
                        || !validation.TryGetProperty("smoke", out var smoke)
                        || !ValidateQuickSmoke(smoke))
                    {
                        throw new InvalidDataException(
                            "A quick-prerelease Windows payload must bind exact passing smoke evidence.");
                    }
                    ValidateQuickEvidence(
                        Path.Combine(source, validationFile),
                        validation,
                        trustedIdentity);
                }
                else if (root.TryGetProperty("validationProfile", out _)
                    || root.TryGetProperty("quickPrereleaseValidation", out _))
                {
                    throw new InvalidDataException(
                        "A formal Windows payload cannot carry quick-prerelease metadata.");
                }
                else
                {
                    ValidateFormalEvidence(
                        Path.Combine(source, validationFile),
                        validation,
                        trustedIdentity);
                }
            }

            var actualFiles = Directory.EnumerateFiles(source, "*", SearchOption.AllDirectories)
                .Select(path => Path.GetRelativePath(source, path))
                .Where(path => !string.Equals(path, ManifestName, StringComparison.OrdinalIgnoreCase))
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            if (declared.Count == 0 || !declared.SetEquals(actualFiles))
            {
                throw new InvalidDataException("Every Windows payload file must have exactly one manifest digest.");
            }
        }
        catch (JsonException error)
        {
            throw new InvalidDataException("The Windows payload manifest is invalid.", error);
        }
    }

    private static void ValidateTrustedIdentity(TrustedPayloadIdentity identity)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(identity.Version);
        if (!IsLowerHex(identity.SourceCommit, 40))
        {
            throw new ArgumentException("The trusted source commit must be a lowercase 40-character Git object ID.", nameof(identity));
        }
        if (!identity.CodexRuntimeSource.StartsWith(OfficialCodexReleasePrefix, StringComparison.Ordinal))
        {
            throw new ArgumentException("The trusted Codex runtime must use the official OpenAI Codex release source.", nameof(identity));
        }
        if (!IsLowerHex(identity.CodexRuntimeSha256, 64))
        {
            throw new ArgumentException("The trusted Codex runtime digest must be lowercase SHA-256.", nameof(identity));
        }
        if (identity.PayloadManifestSha256 is { } manifestDigest && !IsLowerHex(manifestDigest, 64))
        {
            throw new ArgumentException("The trusted payload manifest digest must be lowercase SHA-256.", nameof(identity));
        }
        if (!Enum.IsDefined(identity.Policy))
        {
            throw new ArgumentException("The trusted payload publication policy is unsupported.", nameof(identity));
        }
    }

    private static bool TryReadBoolean(JsonElement element, out bool value)
    {
        if (element.ValueKind == JsonValueKind.True)
        {
            value = true;
            return true;
        }
        if (element.ValueKind == JsonValueKind.False)
        {
            value = false;
            return true;
        }
        value = false;
        return false;
    }

    private static bool ValidateQuickSmoke(JsonElement smoke)
    {
        if (smoke.ValueKind != JsonValueKind.Object
            || !JsonPropertyNamesEqual(
                smoke,
                ["embeddedPayload", "manager", "runtime", "redactedProbe"]))
        {
            return false;
        }
        foreach (var name in new[] { "embeddedPayload", "manager", "runtime" })
        {
            if (!smoke.TryGetProperty(name, out var result)
                || result.ValueKind != JsonValueKind.String
                || result.GetString() != "pass")
            {
                return false;
            }
        }
        if (!smoke.TryGetProperty("redactedProbe", out var probe)
            || probe.ValueKind != JsonValueKind.Object
            || !JsonPropertyNamesEqual(
                probe,
                ["result", "includesText", "rawNodeNameCount"])
            || !probe.TryGetProperty("result", out var probeResult)
            || probeResult.ValueKind != JsonValueKind.String
            || probeResult.GetString() != "pass"
            || !probe.TryGetProperty("includesText", out var includesText)
            || includesText.ValueKind != JsonValueKind.False
            || !probe.TryGetProperty("rawNodeNameCount", out var rawNodeNameCount)
            || rawNodeNameCount.ValueKind != JsonValueKind.Number
            || !rawNodeNameCount.TryGetInt32(out var rawNameCount)
            || rawNameCount != 0)
        {
            return false;
        }
        return true;
    }

    private static void ValidateQuickEvidence(
        string evidencePath,
        JsonElement summary,
        TrustedPayloadIdentity trustedIdentity)
    {
        using var evidenceDocument = JsonDocument.Parse(File.ReadAllText(evidencePath));
        var evidence = evidenceDocument.RootElement;
        if (evidence.ValueKind != JsonValueKind.Object
            || !JsonPropertyNamesEqual(
                evidence,
                [
                    "schemaVersion", "releaseProfile", "version", "sourceCommit", "architecture",
                    "windowsBuild", "codexFileBuild", "completedAt", "smoke",
                ])
            || !evidence.TryGetProperty("schemaVersion", out var schemaVersion)
            || schemaVersion.ValueKind != JsonValueKind.Number
            || !schemaVersion.TryGetInt32(out var schemaValue)
            || schemaValue != 1
            || !evidence.TryGetProperty("releaseProfile", out var evidenceProfile)
            || evidenceProfile.ValueKind != JsonValueKind.String
            || evidenceProfile.GetString() != "quick-prerelease"
            || !evidence.TryGetProperty("version", out var evidenceVersion)
            || evidenceVersion.ValueKind != JsonValueKind.String
            || evidenceVersion.GetString() != trustedIdentity.Version
            || !evidence.TryGetProperty("sourceCommit", out var evidenceSource)
            || evidenceSource.ValueKind != JsonValueKind.String
            || evidenceSource.GetString() != trustedIdentity.SourceCommit
            || !evidence.TryGetProperty("architecture", out var evidenceArchitecture)
            || evidenceArchitecture.ValueKind != JsonValueKind.String
            || evidenceArchitecture.GetString() != "x64"
            || !evidence.TryGetProperty("windowsBuild", out var evidenceWindowsBuild)
            || evidenceWindowsBuild.ValueKind != JsonValueKind.Number
            || !evidenceWindowsBuild.TryGetInt32(out var evidenceWindowsBuildValue)
            || evidenceWindowsBuildValue < 22_000
            || !summary.TryGetProperty("windowsBuild", out var summaryWindowsBuild)
            || !summaryWindowsBuild.TryGetInt32(out var summaryWindowsBuildValue)
            || summaryWindowsBuildValue != evidenceWindowsBuildValue
            || !evidence.TryGetProperty("codexFileBuild", out var evidenceCodexBuild)
            || evidenceCodexBuild.ValueKind != JsonValueKind.String
            || !IsFourPartNumericVersion(evidenceCodexBuild.GetString())
            || !summary.TryGetProperty("codexFileBuild", out var summaryCodexBuild)
            || summaryCodexBuild.ValueKind != JsonValueKind.String
            || summaryCodexBuild.GetString() != evidenceCodexBuild.GetString()
            || !evidence.TryGetProperty("completedAt", out var evidenceCompletedAt)
            || evidenceCompletedAt.ValueKind != JsonValueKind.String
            || !IsUtcSecondTimestamp(evidenceCompletedAt.GetString())
            || !summary.TryGetProperty("completedAt", out var summaryCompletedAt)
            || summaryCompletedAt.ValueKind != JsonValueKind.String
            || summaryCompletedAt.GetString() != evidenceCompletedAt.GetString()
            || !evidence.TryGetProperty("smoke", out var evidenceSmoke)
            || !ValidateQuickSmoke(evidenceSmoke)
            || !summary.TryGetProperty("smoke", out var summarySmoke)
            || !ValidateQuickSmoke(summarySmoke)
            || !QuickSmokeEquals(evidenceSmoke, summarySmoke))
        {
            throw new InvalidDataException(
                "The embedded quick-prerelease validation evidence is invalid or contradicts its manifest.");
        }
    }

    private static void ValidateFormalEvidence(
        string evidencePath,
        JsonElement summary,
        TrustedPayloadIdentity trustedIdentity)
    {
        using var evidenceDocument = JsonDocument.Parse(File.ReadAllText(evidencePath));
        var evidence = evidenceDocument.RootElement;
        if (!JsonPropertyNamesEqual(
                summary,
                ["sha256", "windowsBuild", "codexFileBuild", "completedAt", "caseCounts"])
            || !summary.TryGetProperty("caseCounts", out var caseCounts)
            || !JsonPropertyNamesEqual(
                caseCounts,
                ["visual", "geometry", "interaction", "lifecycle"])
            || !HasExactInteger(caseCounts, "visual", 108)
            || !HasExactInteger(caseCounts, "geometry", 9)
            || !HasExactInteger(caseCounts, "interaction", 6)
            || !HasExactInteger(caseCounts, "lifecycle", 7)
            || evidence.ValueKind != JsonValueKind.Object
            || !JsonPropertyNamesEqual(
                evidence,
                [
                    "schemaVersion", "version", "sourceCommit", "architecture", "windowsBuild",
                    "codexFileBuild", "completedAt", "cases",
                ])
            || !HasExactInteger(evidence, "schemaVersion", 1)
            || !HasExactString(evidence, "version", trustedIdentity.Version)
            || !HasExactString(evidence, "sourceCommit", trustedIdentity.SourceCommit)
            || !HasExactString(evidence, "architecture", "x64")
            || !evidence.TryGetProperty("windowsBuild", out var windowsBuild)
            || windowsBuild.ValueKind != JsonValueKind.Number
            || !windowsBuild.TryGetInt32(out var windowsBuildValue)
            || windowsBuildValue < 22_000
            || !summary.TryGetProperty("windowsBuild", out var summaryWindowsBuild)
            || !summaryWindowsBuild.TryGetInt32(out var summaryWindowsBuildValue)
            || summaryWindowsBuildValue != windowsBuildValue
            || !evidence.TryGetProperty("codexFileBuild", out var codexFileBuild)
            || codexFileBuild.ValueKind != JsonValueKind.String
            || !IsFourPartNumericVersion(codexFileBuild.GetString())
            || !summary.TryGetProperty("codexFileBuild", out var summaryCodexBuild)
            || summaryCodexBuild.ValueKind != JsonValueKind.String
            || summaryCodexBuild.GetString() != codexFileBuild.GetString()
            || !evidence.TryGetProperty("completedAt", out var completedAt)
            || completedAt.ValueKind != JsonValueKind.String
            || !IsUtcSecondTimestamp(completedAt.GetString())
            || !summary.TryGetProperty("completedAt", out var summaryCompletedAt)
            || summaryCompletedAt.ValueKind != JsonValueKind.String
            || summaryCompletedAt.GetString() != completedAt.GetString()
            || !evidence.TryGetProperty("cases", out var cases)
            || cases.ValueKind != JsonValueKind.Object
            || !JsonPropertyNamesEqual(
                cases,
                ["visual", "geometry", "interaction", "lifecycle"])
            || !ValidateFormalVisualCases(cases.GetProperty("visual"))
            || !ValidateFormalNamedCases(
                cases.GetProperty("geometry"),
                "state",
                [
                    "restored-collapsed", "left-expanded", "right-expanded", "right-wide",
                    "left-right-expanded", "bottom-expanded", "narrow-window", "maximized", "fullscreen",
                ])
            || !ValidateFormalNamedCases(
                cases.GetProperty("interaction"),
                "name",
                [
                    "hover", "pin", "keyboard-focus", "no-activation", "resize-drag",
                    "unknown-structure-fail-hidden",
                ])
            || !ValidateFormalNamedCases(
                cases.GetProperty("lifecycle"),
                "name",
                [
                    "sleep-resume", "codex-restart", "codex-upgrade", "authorization",
                    "install", "repair", "uninstall",
                ]))
        {
            throw new InvalidDataException(
                "The embedded formal validation evidence is not the exact complete 130-case matrix.");
        }
    }

    private static bool ValidateFormalVisualCases(JsonElement cases)
    {
        if (cases.ValueKind != JsonValueKind.Array) return false;
        var actual = new HashSet<string>(StringComparer.Ordinal);
        foreach (var item in cases.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object
                || !JsonPropertyNamesEqual(item, ["layout", "theme", "language", "scale", "result"])
                || !item.TryGetProperty("layout", out var layout)
                || layout.ValueKind != JsonValueKind.String
                || !item.TryGetProperty("theme", out var theme)
                || theme.ValueKind != JsonValueKind.String
                || !item.TryGetProperty("language", out var language)
                || language.ValueKind != JsonValueKind.String
                || !item.TryGetProperty("scale", out var scale)
                || scale.ValueKind != JsonValueKind.Number
                || !scale.TryGetInt32(out var scaleValue)
                || !HasExactString(item, "result", "pass"))
            {
                return false;
            }
            actual.Add($"{layout.GetString()}\0{theme.GetString()}\0{language.GetString()}\0{scaleValue}");
        }
        var expected = new HashSet<string>(StringComparer.Ordinal);
        foreach (var layout in new[] { "restored-collapsed", "right-wide", "left-right-expanded" })
            foreach (var theme in new[] { "light", "dark", "system" })
                foreach (var language in new[] { "zh-CN", "zh-TW", "en-US" })
                    foreach (var scale in new[] { 100, 125, 150, 200 })
                    {
                        expected.Add($"{layout}\0{theme}\0{language}\0{scale}");
                    }
        return cases.GetArrayLength() == expected.Count && actual.SetEquals(expected);
    }

    private static bool ValidateFormalNamedCases(
        JsonElement cases,
        string nameProperty,
        IEnumerable<string> expectedNames)
    {
        if (cases.ValueKind != JsonValueKind.Array) return false;
        var actual = new List<string>();
        foreach (var item in cases.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object
                || !JsonPropertyNamesEqual(item, [nameProperty, "result"])
                || !item.TryGetProperty(nameProperty, out var name)
                || name.ValueKind != JsonValueKind.String
                || !HasExactString(item, "result", "pass"))
            {
                return false;
            }
            actual.Add(name.GetString()!);
        }
        var expected = expectedNames.ToHashSet(StringComparer.Ordinal);
        return actual.Count == expected.Count && actual.ToHashSet(StringComparer.Ordinal).SetEquals(expected);
    }

    private static bool HasExactInteger(JsonElement element, string name, int expected) =>
        element.TryGetProperty(name, out var value)
        && value.ValueKind == JsonValueKind.Number
        && value.TryGetInt32(out var actual)
        && actual == expected;

    private static bool HasExactString(JsonElement element, string name, string expected) =>
        element.TryGetProperty(name, out var value)
        && value.ValueKind == JsonValueKind.String
        && value.GetString() == expected;

    private static bool JsonPropertyNamesEqual(JsonElement element, IEnumerable<string> expected)
    {
        var actualNames = element.EnumerateObject().Select(property => property.Name).ToArray();
        var expectedNames = expected.ToArray();
        return actualNames.Length == expectedNames.Length
            && actualNames.ToHashSet(StringComparer.Ordinal).SetEquals(expectedNames);
    }

    private static bool QuickSmokeEquals(JsonElement left, JsonElement right) =>
        new[] { "embeddedPayload", "manager", "runtime" }.All(name =>
            left.GetProperty(name).GetString() == right.GetProperty(name).GetString())
        && left.GetProperty("redactedProbe").GetProperty("result").GetString()
            == right.GetProperty("redactedProbe").GetProperty("result").GetString()
        && left.GetProperty("redactedProbe").GetProperty("includesText").GetBoolean()
            == right.GetProperty("redactedProbe").GetProperty("includesText").GetBoolean()
        && left.GetProperty("redactedProbe").GetProperty("rawNodeNameCount").GetInt32()
            == right.GetProperty("redactedProbe").GetProperty("rawNodeNameCount").GetInt32();

    private static bool IsFourPartNumericVersion(string? value) =>
        value is not null
        && value.Split('.').Length == 4
        && value.Split('.').All(part => part.Length > 0 && part.All(char.IsAsciiDigit));

    private static bool IsUtcSecondTimestamp(string? value) =>
        value is not null
        && DateTimeOffset.TryParseExact(
            value,
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
            out _);

    private static bool IsLowerHex(string value, int length) =>
        value.Length == length && value.All(character =>
            character is >= '0' and <= '9' or >= 'a' and <= 'f');

    private static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);
        foreach (var file in Directory.EnumerateFiles(source))
        {
            File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), overwrite: false);
        }
        foreach (var directory in Directory.EnumerateDirectories(source))
        {
            CopyDirectory(directory, Path.Combine(destination, Path.GetFileName(directory)));
        }
    }

    internal static void ValidateNoLinks(string root)
    {
        foreach (var path in Directory.EnumerateFileSystemEntries(root, "*", SearchOption.AllDirectories).Prepend(root))
        {
            if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("The Windows payload cannot contain links or reparse points.");
            }
        }
    }

    private static void ValidateExistingAncestors(string path)
    {
        for (var current = new DirectoryInfo(path); current is not null; current = current.Parent)
        {
            if (!current.Exists) continue;
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("The install path cannot traverse a link or reparse point.");
            }
        }
    }

    private static bool IsSameOrDescendant(string candidate, string ancestor)
    {
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        var normalizedAncestor = ancestor.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return string.Equals(candidate.TrimEnd(Path.DirectorySeparatorChar), ancestor.TrimEnd(Path.DirectorySeparatorChar), comparison)
            || candidate.StartsWith(normalizedAncestor, comparison);
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path)) File.Delete(path);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}

public sealed record TrustedPayloadIdentity(
    string Version,
    string SourceCommit,
    string CodexRuntimeSource,
    string CodexRuntimeSha256,
    string? PayloadManifestSha256 = null,
    PayloadManifestPolicy Policy = PayloadManifestPolicy.DeviceTest);

public enum PayloadManifestPolicy
{
    DeviceTest,
    PublishedRelease,
}

public interface IPayloadStageValidator
{
    void Validate(string stage, TrustedPayloadIdentity trustedIdentity);
}

public sealed class PayloadStageValidator : IPayloadStageValidator
{
    public void Validate(string stage, TrustedPayloadIdentity trustedIdentity)
    {
        AtomicPayloadInstaller.ValidateNoLinks(stage);
        AtomicPayloadInstaller.ValidateManifest(stage, trustedIdentity);
    }
}

public interface IBackupCleaner
{
    bool TryDelete(string path);
}

internal sealed class BackupCleaner : IBackupCleaner
{
    public bool TryDelete(string path)
    {
        try
        {
            Directory.Delete(path, recursive: true);
            return true;
        }
        catch (IOException)
        {
            return false;
        }
        catch (UnauthorizedAccessException)
        {
            return false;
        }
    }
}
