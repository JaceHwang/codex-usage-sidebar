using System.Security.Cryptography;
using System.Text;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class CompatibilityCatalogRuntimeTests
{
    [TestMethod]
    public async Task ProductionCompositionSuppliesValidatedCachedCatalogToTheRuntimeScannerAndStartsTheUpdater()
    {
        using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var configuration = CompatibilityUpdateConfiguration.Create(
            Convert.ToBase64String(key.ExportSubjectPublicKeyInfo()),
            "https://updates.example.test/selectors.zip");
        var cachedCatalog = Encoding.UTF8.GetBytes(ValidCatalog("cached-runtime-profile"));
        var manifest = CompatibilityCatalogRuntime.CreateManifest(2, cachedCatalog);
        var signature = key.SignData(
            CompatibilityPackUpdater.SignaturePayload(manifest, cachedCatalog),
            HashAlgorithmName.SHA256);
        var updater = new RecordingUpdater();

        var composition = await WindowsCompatibilityRuntime.CreateAsync(
            Encoding.UTF8.GetBytes(ValidCatalog("packaged-profile")),
            configuration,
            new InMemoryCompatibilityPackCache(new CompatibilityPackCacheEntry(
                2, "etag", DateTimeOffset.UtcNow, cachedCatalog, manifest, signature)),
            updater,
            CancellationToken.None);

        Assert.AreEqual("cached-runtime-profile", composition.Scanner.Catalog.ProfilesFor("cached-runtime-profile").Single().BuildIdentities.Single());
        Assert.IsTrue(updater.Started);
    }

    [TestMethod]
    public async Task ProductionCompositionRejectsWrongTypeManifestAndRetainsPackagedCatalogSafely()
    {
        using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var configuration = CompatibilityUpdateConfiguration.Create(
            Convert.ToBase64String(key.ExportSubjectPublicKeyInfo()),
            "https://updates.example.test/selectors.zip");
        var packagedCatalog = Encoding.UTF8.GetBytes(ValidCatalog("packaged-profile"));
        var cachedCatalog = Encoding.UTF8.GetBytes(ValidCatalog("cached-profile"));
        var malformedManifest = Encoding.UTF8.GetBytes($$"""{"sequence":"2","catalogSha256":"{{Convert.ToHexString(SHA256.HashData(cachedCatalog)).ToLowerInvariant()}}"}""");
        var updater = new RecordingUpdater();

        var composition = await WindowsCompatibilityRuntime.CreateAsync(
            packagedCatalog,
            configuration,
            new InMemoryCompatibilityPackCache(new CompatibilityPackCacheEntry(
                2, "etag", DateTimeOffset.UtcNow, cachedCatalog, malformedManifest, [1, 2, 3])),
            updater,
            CancellationToken.None);

        Assert.AreEqual("packaged-profile", composition.Scanner.Catalog.ProfilesFor("packaged-profile").Single().BuildIdentities.Single());
        Assert.IsTrue(updater.Started);
    }

    [DataTestMethod]
    [DataRow(CacheFailureKind.IOException)]
    [DataRow(CacheFailureKind.JsonException)]
    [DataRow(CacheFailureKind.NullData)]
    public async Task CacheLoadFailuresRetainThePackagedCatalogAndDoNotBlockSafeStartup(CacheFailureKind failure)
    {
        var updater = new RecordingUpdater();

        var runtime = await CompatibilityCatalogRuntime.CreateAsync(
            Encoding.UTF8.GetBytes(ValidCatalog("packaged-profile")),
            CompatibilityUpdateConfiguration.Create(Convert.ToBase64String(ECDsa.Create(ECCurve.NamedCurves.nistP256).ExportSubjectPublicKeyInfo()), "https://updates.example.test/selectors.zip"),
            new FailingCompatibilityPackCache(failure),
            updater,
            CancellationToken.None);

        Assert.AreEqual("packaged-profile", runtime.Catalog.ProfilesFor("packaged-profile").Single().BuildIdentities.Single());
        Assert.IsTrue(updater.Started);
    }
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

    public enum CacheFailureKind { IOException, JsonException, NullData }

    private sealed class FailingCompatibilityPackCache(CacheFailureKind failure) : ICompatibilityPackCache
    {
        public ValueTask<CompatibilityPackCacheEntry?> LoadAsync(CancellationToken cancellationToken) => failure switch
        {
            CacheFailureKind.IOException => ValueTask.FromException<CompatibilityPackCacheEntry?>(new IOException("cache unavailable")),
            CacheFailureKind.JsonException => ValueTask.FromException<CompatibilityPackCacheEntry?>(new System.Text.Json.JsonException("cache malformed")),
            CacheFailureKind.NullData => ValueTask.FromResult<CompatibilityPackCacheEntry?>(new CompatibilityPackCacheEntry(1, null, DateTimeOffset.UtcNow, null!)),
            _ => throw new ArgumentOutOfRangeException(nameof(failure)),
        };

        public ValueTask ReplaceAsync(CompatibilityPackCacheEntry replacement, CancellationToken cancellationToken) => ValueTask.CompletedTask;
    }
}
