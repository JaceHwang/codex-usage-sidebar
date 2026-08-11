using System.Text.Json;
using System.Security.Cryptography;
using System.Text.Json.Nodes;

namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class AtomicPayloadInstallerTests
{
    private const string ExpectedVersion = "0.3.0-beta.1";

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
    public void RejectsPayloadSymlinksBeforeReplacingDestination()
    {
        using var fixture = Fixture.Create();
        fixture.WritePayload(ExpectedVersion, "new");
        Directory.CreateDirectory(fixture.Destination);
        File.WriteAllText(Path.Combine(fixture.Destination, "marker.txt"), "old");
        File.CreateSymbolicLink(Path.Combine(fixture.Source, "redirect"), fixture.Destination);

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

    private sealed class RejectingBackupCleaner : IBackupCleaner
    {
        public int Attempts { get; private set; }
        public bool TryDelete(string path) { Attempts++; return false; }
    }

    private sealed class Fixture : IDisposable
    {
        private const string SourceCommit = "0123456789abcdef0123456789abcdef01234567";
        private const string CodexSource = "https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe";
        private static readonly string RuntimeSha256 = Convert.ToHexString(
            SHA256.HashData(System.Text.Encoding.UTF8.GetBytes("runtime"))).ToLowerInvariant();

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

        public AtomicPayloadInstaller Installer(IBackupCleaner? cleaner = null) => new(
            new TrustedPayloadIdentity(ExpectedVersion, SourceCommit, CodexSource, RuntimeSha256),
            cleaner);

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

        public void Dispose() => Directory.Delete(Root, recursive: true);
    }
}
