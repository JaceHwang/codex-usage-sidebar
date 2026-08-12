using System.Text.Json;
using System.Security.Cryptography;

namespace CodexUsageSidebar.Installer;

public sealed class AtomicPayloadInstaller
{
    private const string ManifestName = "windows-payload.json";
    private const string OfficialCodexReleasePrefix = "https://github.com/openai/codex/releases/download/";
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

    public AtomicPayloadInstaller(
        TrustedPayloadIdentity trustedIdentity,
        IBackupCleaner? backupCleaner = null,
        IPayloadStageValidator? stageValidator = null)
    {
        ValidateTrustedIdentity(trustedIdentity);
        this.trustedIdentity = trustedIdentity;
        this.backupCleaner = backupCleaner ?? new BackupCleaner();
        this.stageValidator = stageValidator ?? new PayloadStageValidator();
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
            using (new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
            {
                CopyDirectory(sourcePath, temporary);
                stageValidator.Validate(temporary, trustedIdentity);
                if (Directory.Exists(destinationPath))
                {
                    Directory.Move(destinationPath, backup);
                    movedPrevious = true;
                }
                Directory.Move(temporary, destinationPath);
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
            if (!root.TryGetProperty("status", out var status)
                || status.ValueKind != JsonValueKind.String
                || status.GetString() != "device-test"
                || !root.TryGetProperty("realDeviceValidated", out var realDeviceValidated)
                || realDeviceValidated.ValueKind is not JsonValueKind.False
                || !root.TryGetProperty("publishableInstaller", out var publishableInstaller)
                || publishableInstaller.ValueKind is not JsonValueKind.False)
            {
                throw new InvalidDataException("The Windows device payload must remain explicitly nonpublishable.");
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
    }

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
    string? PayloadManifestSha256 = null);

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
