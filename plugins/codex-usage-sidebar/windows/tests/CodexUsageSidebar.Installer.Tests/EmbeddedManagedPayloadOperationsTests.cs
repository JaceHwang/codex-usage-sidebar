using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class EmbeddedManagedPayloadOperationsTests
{
    [TestMethod]
    public void ValidatesWithoutActivatingThenInstallsFromAFreshPrivateStage()
    {
        using var fixture = Fixture.Create(publishable: true);
        var operations = fixture.Operations();

        operations.Validate();

        Assert.IsFalse(Directory.Exists(fixture.Plan.Paths.CurrentPayload));
        Assert.IsFalse(Directory.Exists(fixture.Plan.PrivateStageParent)
            && Directory.EnumerateFileSystemEntries(fixture.Plan.PrivateStageParent).Any());

        operations.Activate();

        Assert.AreEqual("release", File.ReadAllText(Path.Combine(fixture.Plan.Paths.CurrentPayload, "marker.txt")));
        Assert.IsFalse(Directory.Exists(fixture.Plan.PrivateStageParent)
            && Directory.EnumerateFileSystemEntries(fixture.Plan.PrivateStageParent).Any());
    }

    [TestMethod]
    public void RejectsANonpublishableEmbeddedPayloadBeforeTouchingCurrent()
    {
        using var fixture = Fixture.Create(publishable: false);
        Directory.CreateDirectory(fixture.Plan.Paths.CurrentPayload);
        File.WriteAllText(Path.Combine(fixture.Plan.Paths.CurrentPayload, "marker.txt"), "old");

        Assert.ThrowsException<InvalidDataException>(() => fixture.Operations().Validate());

        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Plan.Paths.CurrentPayload, "marker.txt")));
    }

    [TestMethod]
    public void DiagnosesAnIsolatedActivationThroughTheSameLockAndAtomicInstallPath()
    {
        using var fixture = Fixture.Create(publishable: true);

        var result = EmbeddedActivationDiagnostic.Run(fixture.Source, fixture.Plan);

        CollectionAssert.AreEqual(
            new[] { "operation-lock", "embedded-extract", "atomic-install", "embedded-cleanup", "operation-lock-cleanup" },
            result.CompletedStages.ToArray());
        Assert.AreEqual("release", File.ReadAllText(Path.Combine(fixture.Plan.Paths.CurrentPayload, "marker.txt")));
        Assert.IsFalse(Directory.Exists(fixture.Plan.PrivateStageParent)
            && Directory.EnumerateFileSystemEntries(fixture.Plan.PrivateStageParent).Any());
    }

    [TestMethod]
    public void IdentifiesTheFirstFailingDiagnosticStageWithoutExposingTheRawFailure()
    {
        using var fixture = Fixture.Create(publishable: true);
        Directory.CreateDirectory(fixture.Plan.Paths.InstallRoot);
        using var blocker = new FileStream(
            Path.Combine(fixture.Plan.Paths.InstallRoot, "install.lock"),
            FileMode.OpenOrCreate,
            FileAccess.ReadWrite,
            FileShare.None);

        var error = Assert.ThrowsException<EmbeddedActivationDiagnosticException>(
            () => EmbeddedActivationDiagnostic.Run(fixture.Source, fixture.Plan));

        Assert.AreEqual("operation-lock", error.Stage);
        Assert.IsInstanceOfType<IOException>(error.InnerException);
        Assert.IsFalse(error.Message.Contains(fixture.Plan.Paths.InstallRoot, StringComparison.Ordinal));
    }

    [TestMethod]
    public void ActivationPreservesTheExactSafeStageWhenAtomicInstallationFails()
    {
        using var fixture = Fixture.Create(publishable: true);
        Directory.CreateDirectory(fixture.Plan.Paths.InstallRoot);
        using var blocker = new FileStream(
            Path.Combine(fixture.Plan.Paths.InstallRoot, ".cus-install.lock"),
            FileMode.OpenOrCreate,
            FileAccess.ReadWrite,
            FileShare.None);

        var error = Assert.ThrowsException<InstallerSafeStageException>(
            () => fixture.Operations().Activate());

        Assert.AreEqual("payload-install-lock", error.Stage);
        Assert.IsInstanceOfType<IOException>(error.InnerException);
        Assert.IsFalse(error.Message.Contains(fixture.Plan.Paths.InstallRoot, StringComparison.Ordinal));
    }

    private sealed class Fixture : IDisposable
    {
        private const string Commit = "0123456789abcdef0123456789abcdef01234567";
        private const string RuntimeSource = "https://github.com/openai/codex/releases/download/test/codex.exe";
        private readonly string root;

        private Fixture(string root, bool publishable)
        {
            this.root = root;
            var smoke = new
            {
                embeddedPayload = "pass",
                manager = "pass",
                runtime = "pass",
                redactedProbe = new { result = "pass", includesText = false, rawNodeNameCount = 0 },
            };
            var validationEvidence = JsonSerializer.SerializeToUtf8Bytes(new
            {
                schemaVersion = 1,
                releaseProfile = "quick-prerelease",
                version = "0.3.0",
                sourceCommit = Commit,
                architecture = "x64",
                windowsBuild = 26100,
                codexFileBuild = "151.0.7922.76",
                completedAt = "2026-08-13T00:00:00Z",
                smoke,
            });
            var files = new Dictionary<string, byte[]>(StringComparer.Ordinal)
            {
                ["CodexUsageSidebar.Windows.exe"] = Encoding.UTF8.GetBytes("host"),
                ["CodexUsageSidebar.Control.exe"] = Encoding.UTF8.GetBytes("control"),
                ["codex.exe"] = Encoding.UTF8.GetBytes("runtime"),
                ["selectors.json"] = Encoding.UTF8.GetBytes("{}"),
                ["marker.txt"] = Encoding.UTF8.GetBytes("release"),
                ["windows-validation.json"] = validationEvidence,
            };
            var digests = files.ToDictionary(
                pair => pair.Key,
                pair => Convert.ToHexString(SHA256.HashData(pair.Value)).ToLowerInvariant(),
                StringComparer.Ordinal);
            var manifest = JsonSerializer.SerializeToUtf8Bytes(new
            {
                schemaVersion = 1,
                version = "0.3.0",
                architecture = "x64",
                sourceCommit = Commit,
                status = "release",
                validationProfile = "quick-prerelease",
                realDeviceValidated = false,
                publishableInstaller = publishable,
                codexRuntime = new { source = RuntimeSource, sha256 = digests["codex.exe"] },
                quickPrereleaseValidation = new
                {
                    sha256 = digests["windows-validation.json"],
                    windowsBuild = 26100,
                    codexFileBuild = "151.0.7922.76",
                    completedAt = "2026-08-13T00:00:00Z",
                    smoke,
                },
                files = digests,
            });
            Resources = files.ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal);
            Resources["windows-payload.json"] = manifest;
            var manifestSha256 = Convert.ToHexString(SHA256.HashData(manifest)).ToLowerInvariant();
            Plan = EmbeddedReleaseInstallerPlan.Create(
                root,
                "x64",
                22_000,
                "0.3.0",
                Commit,
                manifestSha256,
                RuntimeSource,
                digests["codex.exe"]);
            Source = new EmbeddedPayloadSource(
                Resources.Keys,
                name => new MemoryStream(Resources[name], writable: false),
                manifestSha256);
        }

        public Dictionary<string, byte[]> Resources { get; }
        public EmbeddedReleaseInstallerPlan Plan { get; }
        public EmbeddedPayloadSource Source { get; }

        public static Fixture Create(bool publishable)
        {
            var root = Path.Combine(Path.GetTempPath(), "cus-embedded-operations-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            return new Fixture(root, publishable);
        }

        public EmbeddedManagedPayloadOperations Operations() => new(Source, Plan);

        public void Dispose()
        {
            if (Directory.Exists(root)) Directory.Delete(root, recursive: true);
        }
    }
}
