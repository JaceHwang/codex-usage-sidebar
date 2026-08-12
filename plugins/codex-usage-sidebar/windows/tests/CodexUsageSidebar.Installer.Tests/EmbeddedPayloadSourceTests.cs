using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class EmbeddedPayloadSourceTests
{
    [TestMethod]
    public void ExtractsOnlyManifestBoundResourcesIntoAPrivateStage()
    {
        using var fixture = Fixture.Create();
        var source = fixture.CreateSource();

        using var lease = source.Extract(fixture.StageParent);

        CollectionAssert.AreEquivalent(
            fixture.Files.Keys.Append("windows-payload.json").ToArray(),
            Directory.EnumerateFiles(lease.PayloadDirectory, "*", SearchOption.AllDirectories)
                .Select(path => Path.GetRelativePath(lease.PayloadDirectory, path).Replace('\\', '/'))
                .ToArray());
        Assert.IsTrue(Path.GetFileName(lease.PayloadDirectory).StartsWith(".cus-embedded-", StringComparison.Ordinal));
        Assert.IsFalse(File.GetAttributes(lease.PayloadDirectory).HasFlag(FileAttributes.ReparsePoint));
    }

    [TestMethod]
    public void RejectsMissingExtraOrDigestMismatchedResources()
    {
        using var fixture = Fixture.Create();

        fixture.Resources.Remove("selectors.json");
        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.CreateSource().Extract(fixture.StageParent));

        fixture.ResetResources();
        fixture.Resources["unexpected.bin"] = Encoding.UTF8.GetBytes("extra");
        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.CreateSource().Extract(fixture.StageParent));

        fixture.ResetResources();
        fixture.Resources["codex.exe"] = Encoding.UTF8.GetBytes("tampered");
        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.CreateSource().Extract(fixture.StageParent));
    }

    [TestMethod]
    public void RejectsAnUntrustedManifestAndCleansThePrivateStage()
    {
        using var fixture = Fixture.Create();
        fixture.TrustedManifestSha256 = new string('a', 64);

        Assert.ThrowsException<InvalidDataException>(() =>
            fixture.CreateSource().Extract(fixture.StageParent));
        Assert.IsFalse(Directory.Exists(fixture.StageParent)
            && Directory.EnumerateFileSystemEntries(fixture.StageParent).Any());
    }

    [TestMethod]
    public void DisposingTheLeaseRemovesTheExtractedPayload()
    {
        using var fixture = Fixture.Create();
        var lease = fixture.CreateSource().Extract(fixture.StageParent);
        var extracted = lease.PayloadDirectory;

        lease.Dispose();

        Assert.IsFalse(Directory.Exists(extracted));
    }

    private sealed class Fixture : IDisposable
    {
        private Fixture(string root)
        {
            Root = root;
            StageParent = Path.Combine(root, "stages");
            Files = new Dictionary<string, byte[]>(StringComparer.Ordinal)
            {
                ["CodexUsageSidebar.Windows.exe"] = Encoding.UTF8.GetBytes("host"),
                ["CodexUsageSidebar.Control.exe"] = Encoding.UTF8.GetBytes("control"),
                ["codex.exe"] = Encoding.UTF8.GetBytes("runtime"),
                ["selectors.json"] = Encoding.UTF8.GetBytes("{\"schemaVersion\":1,\"builds\":[]}"),
            };
            ResetResources();
        }

        public string Root { get; }
        public string StageParent { get; }
        public Dictionary<string, byte[]> Files { get; }
        public Dictionary<string, byte[]> Resources { get; private set; } = new(StringComparer.Ordinal);
        public string TrustedManifestSha256 { get; set; } = string.Empty;

        public static Fixture Create()
        {
            var root = Path.Combine(Path.GetTempPath(), "cus-embedded-tests-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            return new Fixture(root);
        }

        public void ResetResources()
        {
            var fileDigests = Files.ToDictionary(
                pair => pair.Key,
                pair => Convert.ToHexString(SHA256.HashData(pair.Value)).ToLowerInvariant(),
                StringComparer.Ordinal);
            var manifest = JsonSerializer.SerializeToUtf8Bytes(new
            {
                schemaVersion = 1,
                files = fileDigests,
            });
            Resources = Files.ToDictionary(pair => pair.Key, pair => pair.Value.ToArray(), StringComparer.Ordinal);
            Resources["windows-payload.json"] = manifest;
            TrustedManifestSha256 = Convert.ToHexString(SHA256.HashData(manifest)).ToLowerInvariant();
        }

        public EmbeddedPayloadSource CreateSource() => new(
            Resources.Keys,
            name => new MemoryStream(Resources[name], writable: false),
            TrustedManifestSha256);

        public void Dispose()
        {
            if (Directory.Exists(Root)) Directory.Delete(Root, recursive: true);
        }
    }
}
