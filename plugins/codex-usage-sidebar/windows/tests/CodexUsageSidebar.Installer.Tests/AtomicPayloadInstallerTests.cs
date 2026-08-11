using System.Text.Json;
using System.Security.Cryptography;

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

        new AtomicPayloadInstaller().Install(fixture.Source, fixture.Destination, ExpectedVersion);

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
            new AtomicPayloadInstaller().Install(fixture.Source, fixture.Destination, ExpectedVersion));

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
            new AtomicPayloadInstaller().Install(fixture.Source, fixture.Destination, ExpectedVersion));
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
            new AtomicPayloadInstaller().Install(fixture.Source, fixture.Destination, ExpectedVersion));
        Assert.AreEqual("old", File.ReadAllText(Path.Combine(fixture.Destination, "marker.txt")));
    }

    private sealed class Fixture : IDisposable
    {
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

        public void WritePayload(string version, string marker)
        {
            Directory.CreateDirectory(Source);
            File.WriteAllText(Path.Combine(Source, "marker.txt"), marker);
            var digest = Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(marker))).ToLowerInvariant();
            File.WriteAllText(Path.Combine(Source, "windows-payload.json"), JsonSerializer.Serialize(new
            {
                version,
                architecture = "x64",
                files = new Dictionary<string, string> { ["marker.txt"] = digest },
            }));
        }

        public void Dispose() => Directory.Delete(Root, recursive: true);
    }
}
