using System.Diagnostics;
using System.Text.Json;
using System.Security.Cryptography;
using System.Text.Json.Nodes;

namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class AtomicPayloadInstallerTests
{
    private const string ExpectedVersion = "0.3.0";

    [TestMethod]
    public void InstallsAndAtomicallyReplacesVersionMatchedPayload()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        Directory.CreateDirectory(fixture.Destination);
        File.WriteAllText(Path.Combine(fixture.Destination, "marker.txt"), "old");

        fixture.Installer().Install(fixture.Source, fixture.Destination);

        Assert.AreEqual("new", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
        Assert.IsFalse(Directory.EnumerateDirectories(fixture.Root).Any(path =>
            Path.GetFileName(path).StartsWith(".cus-", StringComparison.Ordinal)));
    }

    [TestMethod]
    public void VersionMismatchLeavesExistingPayloadUntouched()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload("0.3.0-beta.2", "new");
        Directory.CreateDirectory(fixture.Destination);
        File.WriteAllText(Path.Combine(fixture.Destination, "marker.txt"), "old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));

        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void RejectsPayloadReparsePointsBeforeReplacingDestination()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        Directory.CreateDirectory(fixture.Destination);
        File.WriteAllText(Path.Combine(fixture.Destination, "marker.txt"), "old");
        fixture.CreatePayloadDirectoryLink("redirect", fixture.Destination);

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void DigestMismatchLeavesExistingPayloadUntouched()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        File.WriteAllText(Path.Combine(fixture.Source, "marker.txt"), "tampered");
        Directory.CreateDirectory(fixture.Destination);
        File.WriteAllText(Path.Combine(fixture.Destination, "marker.txt"), "old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void BackupCleanupFailureKeepsTheNewPayloadActive()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        Directory.CreateDirectory(fixture.Destination);
        File.WriteAllText(Path.Combine(fixture.Destination, "marker.txt"), "old");
        var cleaner = new RejectingBackupCleaner();

        fixture.Installer(cleaner).Install(fixture.Source, fixture.Destination);

        Assert.AreEqual("new", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
        Assert.AreEqual(1, cleaner.Attempts);
        Assert.IsTrue(Directory.EnumerateDirectories(fixture.Root).Any(path =>
            Path.GetFileName(path).StartsWith(".cus-backup-", StringComparison.Ordinal)));
    }

    [TestMethod]
    public void MissingCodexRuntimeProvenanceLeavesExistingPayloadUntouched()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.RemoveManifestProperty("codexRuntime");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void MissingRequiredHostExecutableLeavesExistingPayloadUntouched()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        File.Delete(Path.Combine(fixture.Source, "CodexUsageSidebar.Windows.exe"));
        fixture.RemoveDeclaredFile("CodexUsageSidebar.Windows.exe");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PayloadCannotReplaceTheInstallerTrustedSourceIdentity()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.SetManifestString("sourceCommit", "fedcba9876543210fedcba9876543210fedcba98");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PayloadCannotReplaceTheInstallerTrustedCodexSource()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.SetCodexRuntimeSource("https://example.invalid/codex.exe");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PublishablePayloadCannotUseTheDeviceTestInstaller()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.SetManifestBoolean("publishableInstaller", true);
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PayloadWithoutDeviceTestStatusCannotUseTheDeviceTestInstaller()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.RemoveManifestProperty("status");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PublishedReleasePayloadRequiresAnExplicitPublishedReleaseTrustPolicy()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakePublishedRelease(publishable: true, exactEvidence: true);
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        fixture.Installer(PayloadManifestPolicy.PublishedRelease)
            .Install(fixture.Source, fixture.Destination);

        Assert.AreEqual("new", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PublishedReleaseTrustPolicyRejectsAnUnvalidatedOrNonpublishablePayload()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakePublishedRelease(publishable: false);
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(PayloadManifestPolicy.PublishedRelease)
                .Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PublishedReleaseTrustPolicyRejectsPayloadWithoutBoundValidationEvidence()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakePublishedRelease(publishable: true);
        File.Delete(Path.Combine(fixture.Source, "windows-validation.json"));
        fixture.RemoveDeclaredFile("windows-validation.json");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(PayloadManifestPolicy.PublishedRelease)
                .Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void PublishedReleaseTrustPolicyAcceptsExactQuickPrereleasePayload()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakeQuickPrerelease();
        fixture.WriteExistingPayload("old");

        fixture.Installer(PayloadManifestPolicy.PublishedRelease)
            .Install(fixture.Source, fixture.Destination);

        Assert.AreEqual("new", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void QuickPrereleasePayloadCannotClaimRealDeviceValidation()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakeQuickPrerelease();
        fixture.SetManifestBoolean("realDeviceValidated", true);
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(PayloadManifestPolicy.PublishedRelease)
                .Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void FormalPayloadCannotCarryQuickPrereleaseProfile()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakePublishedRelease(publishable: true);
        fixture.SetManifestString("validationProfile", "quick-prerelease");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(PayloadManifestPolicy.PublishedRelease)
                .Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void QuickPrereleasePayloadRequiresItsDistinctValidationBinding()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakeQuickPrerelease();
        fixture.ReplaceQuickValidationWithFormalBinding();
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(PayloadManifestPolicy.PublishedRelease)
                .Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void QuickPrereleasePayloadRejectsNonpassingEmbeddedSmokeEvidence()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakeQuickPrerelease();
        fixture.SetQuickEvidenceManagerResult("fail");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(PayloadManifestPolicy.PublishedRelease)
                .Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void FormalPayloadRequiresTheExactCompleteMatrixEvidence()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.MakePublishedRelease(publishable: true);
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(PayloadManifestPolicy.PublishedRelease)
                .Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));

        fixture.MakePublishedRelease(publishable: true, exactEvidence: true);
        fixture.Installer(PayloadManifestPolicy.PublishedRelease)
            .Install(fixture.Source, fixture.Destination);
        Assert.AreEqual("new", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void DeviceTestPayloadRejectsReleaseProfileMetadata()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.SetManifestString("validationProfile", "quick-prerelease");
        fixture.WriteExistingPayload("old");

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer().Install(fixture.Source, fixture.Destination));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void RejectsAStageTamperedAfterCopyBeforeActivation()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.WriteExistingPayload("old");
        var validator = new TamperingStageValidator();

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.Installer(stageValidator: validator).Install(fixture.Source, fixture.Destination));

        Assert.AreEqual(1, validator.CallCount);
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    [TestMethod]
    public void ReportsAConstantSafeStageWhenStagedPayloadValidationFails()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        const string sensitiveMessage = @"Access denied at C:\Users\fixture\secret token=do-not-display";
        var cause = new IOException(sensitiveMessage);

        var error = Assert.ThrowsException<InstallerSafeStageException>(() =>
            fixture.Installer(stageValidator: new ThrowingStageValidator(cause), reportSafeStages: true)
                .Install(fixture.Source, fixture.Destination));

        Assert.AreEqual("payload-validation", error.Stage);
        Assert.AreSame(cause, error.InnerException);
        Assert.IsFalse(error.Message.Contains(sensitiveMessage, StringComparison.Ordinal));
        Assert.IsFalse(Directory.Exists(fixture.Destination));
    }

    [TestMethod]
    public void RetriesPreviousPayloadMoveUntilARecentHostHandleDrains()
    {
        if (!OperatingSystem.IsWindows())
        {
            Assert.Inconclusive("Windows directory handle semantics are required.");
        }

        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        fixture.WriteExistingPayload("old");
        using var handle = new FileStream(
            Path.Combine(fixture.Destination, "marker.txt"),
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read);
        using var releaseHandle = new Timer(_ => handle.Dispose(), null, 800, Timeout.Infinite);

        fixture.Installer(reportSafeStages: true)
            .Install(fixture.Source, fixture.Destination);

        Assert.AreEqual("new", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
        Assert.IsFalse(Directory.EnumerateDirectories(fixture.Root).Any(path =>
            Path.GetFileName(path).StartsWith(".cus-", StringComparison.Ordinal)));
    }

    private sealed class RejectingBackupCleaner : IBackupCleaner
    {
        public int Attempts { get; private set; }
        public bool TryDelete(string path) { Attempts++; return false; }
    }

    private sealed class TamperingStageValidator : IPayloadStageValidator
    {
        private readonly PayloadStageValidator inner = new();
        public int CallCount { get; private set; }

        public void Validate(string stage, TrustedPayloadIdentity trustedIdentity)
        {
            CallCount++;
            File.WriteAllText(Path.Combine(stage, "marker.txt"), "tampered-after-copy");
            inner.Validate(stage, trustedIdentity);
        }
    }

    private sealed class ThrowingStageValidator(Exception error) : IPayloadStageValidator
    {
        public void Validate(string stage, TrustedPayloadIdentity trustedIdentity) => throw error;
    }

    private sealed class Fixture : IDisposable
    {
        private const string SourceCommit = "0123456789abcdef0123456789abcdef01234567";
        private const string CodexSource = "https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe";
        private static readonly string RuntimeSha256 = Convert.ToHexString(
            SHA256.HashData(System.Text.Encoding.UTF8.GetBytes("runtime"))).ToLowerInvariant();
        private readonly List<string> directoryLinks = [];

        private Fixture(string root)
        {
            Root = root;
            Source = Path.Combine(root, "source");
            Destination = Path.Combine(root, "current");
        }

        public string Root { get; }
        public string Source { get; }
        public string Destination { get; }

        public static Fixture Create()
        {
            var root = Path.Combine(Path.GetTempPath(), "cus-installer-tests-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            return new Fixture(root);
        }

        public AtomicPayloadInstaller Installer(
            IBackupCleaner? cleaner = null,
            IPayloadStageValidator? stageValidator = null,
            bool reportSafeStages = false) => new(
                new TrustedPayloadIdentity(ExpectedVersion, SourceCommit, CodexSource, RuntimeSha256),
                cleaner,
                stageValidator,
                reportSafeStages);

        public AtomicPayloadInstaller Installer(PayloadManifestPolicy policy) => new(
            new TrustedPayloadIdentity(ExpectedVersion, SourceCommit, CodexSource, RuntimeSha256, Policy: policy));

        public void WritePayload(string version, string marker)
        {
            Directory.CreateDirectory(Source);
            var contents = new Dictionary<string, string>
            {
                ["marker.txt"] = marker,
                ["CodexUsageSidebar.Windows.exe"] = "host",
                ["CodexUsageSidebar.Control.exe"] = "control",
                ["codex.exe"] = "runtime",
                ["selectors.json"] = "{\"schemaVersion\":1,\"builds\":[]}",
            };
            foreach (var (name, content) in contents)
            {
                File.WriteAllText(Path.Combine(Source, name), content);
            }
            var files = contents.ToDictionary(
                pair => pair.Key,
                pair => Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(pair.Value))).ToLowerInvariant());
            File.WriteAllText(Path.Combine(Source, "windows-payload.json"), JsonSerializer.Serialize(new
            {
                schemaVersion = 1,
                version,
                architecture = "x64",
                sourceCommit = SourceCommit,
                status = "device-test",
                realDeviceValidated = false,
                publishableInstaller = false,
                codexRuntime = new
                {
                    source = CodexSource,
                    sha256 = files["codex.exe"],
                },
                files,
            }));
        }

        public void WriteExistingPayload(string marker)
        {
            Directory.CreateDirectory(Destination);
            File.WriteAllText(Path.Combine(Destination, "marker.txt"), marker);
        }

        public void CreatePayloadDirectoryLink(string name, string target)
        {
            var link = Path.Combine(Source, name);
            if (!OperatingSystem.IsWindows())
            {
                Directory.CreateSymbolicLink(link, target);
                directoryLinks.Add(link);
                return;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.System),
                    "cmd.exe"),
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };
            foreach (var argument in new[] { "/d", "/c", "mklink", "/J", link, target })
            {
                startInfo.ArgumentList.Add(argument);
            }

            using var process = Process.Start(startInfo)
                ?? throw new InvalidOperationException("Could not start the Windows junction helper.");
            var standardOutput = process.StandardOutput.ReadToEnd();
            var standardError = process.StandardError.ReadToEnd();
            process.WaitForExit();
            if (process.ExitCode != 0)
            {
                throw new IOException(
                    $"Could not create a Windows test junction (exit {process.ExitCode}): "
                    + standardError + standardOutput);
            }
            directoryLinks.Add(link);
        }

        public void RemoveManifestProperty(string property)
        {
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            document.Remove(property);
            File.WriteAllText(path, document.ToJsonString());
        }

        public void RemoveDeclaredFile(string file)
        {
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            document["files"]!.AsObject().Remove(file);
            File.WriteAllText(path, document.ToJsonString());
        }


        public void SetManifestString(string property, string value)
        {
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            document[property] = value;
            File.WriteAllText(path, document.ToJsonString());
        }

        public void SetCodexRuntimeSource(string source)
        {
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            document["codexRuntime"]!["source"] = source;
            File.WriteAllText(path, document.ToJsonString());
        }

        public void SetManifestBoolean(string property, bool value)
        {
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            document[property] = value;
            File.WriteAllText(path, document.ToJsonString());
        }

        public void MakePublishedRelease(bool publishable, bool exactEvidence = false)
        {
            var evidencePath = Path.Combine(Source, "windows-validation.json");
            File.WriteAllText(
                evidencePath,
                exactEvidence ? CreateFormalEvidence().ToJsonString() : "validation-evidence");
            var evidenceSha256 = Convert.ToHexString(
                SHA256.HashData(File.ReadAllBytes(evidencePath))).ToLowerInvariant();
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            document["status"] = "release";
            document["realDeviceValidated"] = true;
            document["publishableInstaller"] = publishable;
            document["files"]!["windows-validation.json"] = evidenceSha256;
            document["realDeviceValidation"] = new JsonObject
            {
                ["sha256"] = evidenceSha256,
                ["windowsBuild"] = 26100,
                ["codexFileBuild"] = "151.0.7922.76",
                ["completedAt"] = "2026-08-13T00:00:00Z",
                ["caseCounts"] = new JsonObject
                {
                    ["visual"] = 108,
                    ["geometry"] = 9,
                    ["interaction"] = 6,
                    ["lifecycle"] = 7,
                },
            };
            File.WriteAllText(path, document.ToJsonString());
        }

        private static JsonObject CreateFormalEvidence()
        {
            var visual = new JsonArray();
            foreach (var layout in new[] { "restored-collapsed", "right-wide", "left-right-expanded" })
                foreach (var theme in new[] { "light", "dark", "system" })
                    foreach (var language in new[] { "zh-CN", "zh-TW", "en-US" })
                        foreach (var scale in new[] { 100, 125, 150, 200 })
                        {
                            visual.Add(new JsonObject
                            {
                                ["layout"] = layout,
                                ["theme"] = theme,
                                ["language"] = language,
                                ["scale"] = scale,
                                ["result"] = "pass",
                            });
                        }
            static JsonArray States(string key, IEnumerable<string> names) =>
                new(names.Select(name => (JsonNode)new JsonObject
                {
                    [key] = name,
                    ["result"] = "pass",
                }).ToArray());
            return new JsonObject
            {
                ["schemaVersion"] = 1,
                ["version"] = ExpectedVersion,
                ["sourceCommit"] = SourceCommit,
                ["architecture"] = "x64",
                ["windowsBuild"] = 26100,
                ["codexFileBuild"] = "151.0.7922.76",
                ["completedAt"] = "2026-08-13T00:00:00Z",
                ["cases"] = new JsonObject
                {
                    ["visual"] = visual,
                    ["geometry"] = States("state", [
                        "restored-collapsed", "left-expanded", "right-expanded", "right-wide",
                        "left-right-expanded", "bottom-expanded", "narrow-window", "maximized", "fullscreen",
                    ]),
                    ["interaction"] = States("name", [
                        "hover", "pin", "keyboard-focus", "no-activation", "resize-drag",
                        "unknown-structure-fail-hidden",
                    ]),
                    ["lifecycle"] = States("name", [
                        "sleep-resume", "codex-restart", "codex-upgrade", "authorization",
                        "install", "repair", "uninstall",
                    ]),
                },
            };
        }

        public void MakeQuickPrerelease()
        {
            var evidencePath = Path.Combine(Source, "windows-validation.json");
            var smoke = new JsonObject
            {
                ["embeddedPayload"] = "pass",
                ["manager"] = "pass",
                ["runtime"] = "pass",
                ["redactedProbe"] = new JsonObject
                {
                    ["result"] = "pass",
                    ["includesText"] = false,
                    ["rawNodeNameCount"] = 0,
                },
            };
            var evidence = new JsonObject
            {
                ["schemaVersion"] = 1,
                ["releaseProfile"] = "quick-prerelease",
                ["version"] = ExpectedVersion,
                ["sourceCommit"] = SourceCommit,
                ["architecture"] = "x64",
                ["windowsBuild"] = 26100,
                ["codexFileBuild"] = "151.0.7922.76",
                ["completedAt"] = "2026-08-13T00:00:00Z",
                ["smoke"] = smoke,
            };
            File.WriteAllText(evidencePath, evidence.ToJsonString());
            var evidenceSha256 = Convert.ToHexString(
                SHA256.HashData(File.ReadAllBytes(evidencePath))).ToLowerInvariant();
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            document["status"] = "release";
            document["validationProfile"] = "quick-prerelease";
            document["realDeviceValidated"] = false;
            document["publishableInstaller"] = true;
            document["files"]!["windows-validation.json"] = evidenceSha256;
            document.Remove("realDeviceValidation");
            document["quickPrereleaseValidation"] = new JsonObject
            {
                ["sha256"] = evidenceSha256,
                ["windowsBuild"] = 26100,
                ["codexFileBuild"] = "151.0.7922.76",
                ["completedAt"] = "2026-08-13T00:00:00Z",
                ["smoke"] = smoke.DeepClone(),
            };
            File.WriteAllText(path, document.ToJsonString());
        }

        public void ReplaceQuickValidationWithFormalBinding()
        {
            var path = Path.Combine(Source, "windows-payload.json");
            var document = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
            var digest = document["files"]!["windows-validation.json"]!.GetValue<string>();
            document.Remove("quickPrereleaseValidation");
            document["realDeviceValidation"] = new JsonObject { ["sha256"] = digest };
            File.WriteAllText(path, document.ToJsonString());
        }

        public void SetQuickEvidenceManagerResult(string result)
        {
            var evidencePath = Path.Combine(Source, "windows-validation.json");
            var evidence = JsonNode.Parse(File.ReadAllText(evidencePath))!.AsObject();
            evidence["smoke"]!["manager"] = result;
            File.WriteAllText(evidencePath, evidence.ToJsonString());
            var digest = Convert.ToHexString(
                SHA256.HashData(File.ReadAllBytes(evidencePath))).ToLowerInvariant();
            var manifestPath = Path.Combine(Source, "windows-payload.json");
            var manifest = JsonNode.Parse(File.ReadAllText(manifestPath))!.AsObject();
            manifest["files"]!["windows-validation.json"] = digest;
            manifest["quickPrereleaseValidation"]!["sha256"] = digest;
            File.WriteAllText(manifestPath, manifest.ToJsonString());
        }

        public void Dispose()
        {
            foreach (var link in directoryLinks)
            {
                if (Directory.Exists(link)) Directory.Delete(link);
            }
            Directory.Delete(Root, recursive: true);
        }
    }
}
