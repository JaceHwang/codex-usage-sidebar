using System.Security.Cryptography;
using System.Text;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class CompatibilityCatalogRuntimeTests
{
    [TestMethod]
    public async Task UsesValidatedSignedCacheBeforePackagedCatalogAndStartsUpdaterInBackground()
    {
        using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var configuration = CompatibilityUpdateConfiguration.Create(
            Convert.ToBase64String(key.ExportSubjectPublicKeyInfo()),
            "https://updates.example.test/selectors.zip");
        var cachedCatalog = Encoding.UTF8.GetBytes(ValidCatalog("cached-profile"));
        var manifest = CompatibilityCatalogRuntime.CreateManifest(2, cachedCatalog);
        var signature = key.SignData(
            CompatibilityPackUpdater.SignaturePayload(manifest, cachedCatalog),
            HashAlgorithmName.SHA256);
        var cache = new InMemoryCompatibilityPackCache(new CompatibilityPackCacheEntry(
            2, "etag", DateTimeOffset.UtcNow, cachedCatalog, manifest, signature));
        var updater = new RecordingUpdater();

        var runtime = await CompatibilityCatalogRuntime.CreateAsync(
            Encoding.UTF8.GetBytes(ValidCatalog("packaged-profile")),
            configuration,
            cache,
            updater,
            CancellationToken.None);

        Assert.AreEqual("cached-profile", runtime.Catalog.ProfilesFor("none").Single().BuildIdentities.Single());
        Assert.IsTrue(updater.Started);
    }

    [TestMethod]
    public async Task RejectsUnsignedCacheAndKeepsPackagedCatalogWhenConfigurationIsInvalid()
    {
        var cache = new InMemoryCompatibilityPackCache(new CompatibilityPackCacheEntry(
            2, "etag", DateTimeOffset.UtcNow, Encoding.UTF8.GetBytes(ValidCatalog("cached-profile")),
            Encoding.UTF8.GetBytes("{}"), [1, 2, 3]));
        var updater = new RecordingUpdater();

        var runtime = await CompatibilityCatalogRuntime.CreateAsync(
            Encoding.UTF8.GetBytes(ValidCatalog("packaged-profile")),
            CompatibilityUpdateConfiguration.Invalid,
            cache,
            updater,
            CancellationToken.None);

        Assert.AreEqual("packaged-profile", runtime.Catalog.ProfilesFor("none").Single().BuildIdentities.Single());
        Assert.IsFalse(updater.Started);
    }

    private static string ValidCatalog(string identity) => $$"""{"schemaVersion":2,"profiles":[{"buildIdentities":["{{identity}}"],"markerAliases":{},"maxWrapperDepth":2,"depthTolerance":2}]}""";

    private sealed class RecordingUpdater : ICompatibilityCatalogUpdater
    {
        public bool Started { get; private set; }
        public void Start() => Started = true;
    }

    private sealed class InMemoryCompatibilityPackCache(CompatibilityPackCacheEntry? entry) : ICompatibilityPackCache
    {
        public ValueTask<CompatibilityPackCacheEntry?> LoadAsync(CancellationToken cancellationToken) => ValueTask.FromResult(entry);
        public ValueTask ReplaceAsync(CompatibilityPackCacheEntry replacement, CancellationToken cancellationToken) => ValueTask.CompletedTask;
    }
}
