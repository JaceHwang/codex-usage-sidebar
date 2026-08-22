namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class EmbeddedReleaseInstallerMetadataTests
{
    [TestMethod]
    public void RequiresEveryEmbeddedReleaseTrustBinding()
    {
        var metadata = CompleteMetadata();
        var parsed = EmbeddedReleaseInstallerMetadata.TryCreate(metadata);

        Assert.IsNotNull(parsed);
        Assert.AreEqual("0.3.1", parsed.Version);
        Assert.AreEqual("0123456789abcdef0123456789abcdef01234567", parsed.SourceCommit);
        Assert.AreEqual("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", parsed.PayloadManifestSha256);

        foreach (var key in metadata.Keys.ToArray())
        {
            var incomplete = CompleteMetadata();
            incomplete.Remove(key);
            Assert.IsNull(EmbeddedReleaseInstallerMetadata.TryCreate(incomplete), key);
        }
    }

    private static Dictionary<string, string?> CompleteMetadata() => new(StringComparer.Ordinal)
    {
        [EmbeddedReleaseInstallerMetadata.VersionKey] = "0.3.1",
        [EmbeddedReleaseInstallerMetadata.SourceCommitKey] = "0123456789abcdef0123456789abcdef01234567",
        [EmbeddedReleaseInstallerMetadata.PayloadManifestSha256Key] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        [EmbeddedReleaseInstallerMetadata.CodexRuntimeSourceKey] = "https://github.com/openai/codex/releases/download/test/codex.exe",
        [EmbeddedReleaseInstallerMetadata.CodexRuntimeSha256Key] = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
}
