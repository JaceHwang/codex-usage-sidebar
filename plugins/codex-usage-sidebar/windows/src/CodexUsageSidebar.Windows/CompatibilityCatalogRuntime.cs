using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace CodexUsageSidebar.Windows;

public sealed record CompatibilityUpdateConfiguration(byte[] PublicKey, Uri UpdateUri, bool IsValid)
{
    public static CompatibilityUpdateConfiguration Invalid { get; } = new(Array.Empty<byte>(), new Uri("https://invalid.local/"), false);

    public static CompatibilityUpdateConfiguration Create(string publicKeyBase64, string updateUri)
    {
        try
        {
            var key = Convert.FromBase64String(publicKeyBase64);
            using var verifier = ECDsa.Create();
            verifier.ImportSubjectPublicKeyInfo(key, out var consumed);
            if (consumed != key.Length || verifier.KeySize != 256
                || !Uri.TryCreate(updateUri, UriKind.Absolute, out var uri)
                || !string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.Ordinal)) return Invalid;
            return new CompatibilityUpdateConfiguration(key, uri, true);
        }
        catch (CryptographicException) { return Invalid; }
        catch (FormatException) { return Invalid; }
    }
}

public interface ICompatibilityCatalogUpdater { void Start(); }

public sealed record CompatibilityCatalogRuntime(SelectorProfileCatalog Catalog)
{
    public static async ValueTask<CompatibilityCatalogRuntime> CreateAsync(
        byte[] packagedCatalog,
        CompatibilityUpdateConfiguration configuration,
        ICompatibilityPackCache cache,
        ICompatibilityCatalogUpdater updater,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(packagedCatalog);
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(cache);
        ArgumentNullException.ThrowIfNull(updater);
        if (!SelectorProfileCatalog.TryParse(Encoding.UTF8.GetString(packagedCatalog), out var packaged))
        {
            throw new InvalidSelectorCatalogException();
        }

        var selected = packaged;
        if (configuration.IsValid)
        {
            try
            {
                var cached = await cache.LoadAsync(cancellationToken).ConfigureAwait(false);
                if (cached is not null && IsSignedCatalog(cached, configuration.PublicKey, out var verified)) selected = verified;
            }
            catch (IOException) { }
            catch (JsonException) { }
            catch (UnauthorizedAccessException) { }
            catch (NullReferenceException) { }
            updater.Start();
        }
        return new CompatibilityCatalogRuntime(selected);
    }

    public static byte[] CreateManifest(long sequence, byte[] catalog) => Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new
    {
        sequence,
        catalogSha256 = Convert.ToHexString(SHA256.HashData(catalog)).ToLowerInvariant(),
    }));

    private static bool IsSignedCatalog(CompatibilityPackCacheEntry cache, byte[] publicKey, out SelectorProfileCatalog catalog)
    {
        catalog = SelectorProfileCatalog.Default;
        if (cache.Catalog is null || cache.Manifest is null || cache.Signature is null || cache.Sequence < 1
            || !SelectorProfileCatalog.TryParse(Encoding.UTF8.GetString(cache.Catalog), out catalog)) return false;
        try
        {
            using var document = JsonDocument.Parse(cache.Manifest);
            if (!document.RootElement.TryGetProperty("sequence", out var sequence) || sequence.GetInt64() != cache.Sequence
                || !document.RootElement.TryGetProperty("catalogSha256", out var digest)
                || !CryptographicOperations.FixedTimeEquals(Convert.FromHexString(digest.GetString() ?? string.Empty), SHA256.HashData(cache.Catalog))) return false;
            using var verifier = ECDsa.Create();
            verifier.ImportSubjectPublicKeyInfo(publicKey, out var consumed);
            return consumed == publicKey.Length && verifier.KeySize == 256 && verifier.VerifyData(
                CompatibilityPackUpdater.SignaturePayload(cache.Manifest, cache.Catalog), cache.Signature, HashAlgorithmName.SHA256);
        }
        catch (CryptographicException) { return false; }
        catch (JsonException) { return false; }
        catch (FormatException) { return false; }
    }
}

#if WINDOWS
public sealed record WindowsCompatibilityRuntime(ValidatedUiaTitlebarScanner Scanner)
{
    public static async ValueTask<WindowsCompatibilityRuntime> CreateAsync(
        byte[] packagedCatalog,
        CompatibilityUpdateConfiguration configuration,
        ICompatibilityPackCache cache,
        ICompatibilityCatalogUpdater updater,
        CancellationToken cancellationToken)
    {
        var catalog = await CompatibilityCatalogRuntime.CreateAsync(
            packagedCatalog, configuration, cache, updater, cancellationToken).ConfigureAwait(false);
        return new WindowsCompatibilityRuntime(new ValidatedUiaTitlebarScanner(catalog.Catalog));
    }
}
#endif

public sealed class BackgroundCompatibilityCatalogUpdater(CompatibilityPackUpdater updater) : ICompatibilityCatalogUpdater
{
    public void Start() => _ = Task.Run(async () =>
    {
        try { await updater.UpdateAsync(CancellationToken.None).ConfigureAwait(false); }
        catch (Exception) { }
    });
}

public sealed class HttpCompatibilityPackTransport(Uri updateUri) : ICompatibilityPackTransport
{
    private static readonly HttpClient Client = new();

    public async ValueTask<CompatibilityPackResponse> GetAsync(string? etag, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, updateUri);
        if (!string.IsNullOrWhiteSpace(etag)) request.Headers.TryAddWithoutValidation("If-None-Match", etag);
        using var response = await Client.SendAsync(request, cancellationToken).ConfigureAwait(false);
        return new CompatibilityPackResponse((int)response.StatusCode, response.Headers.ETag?.ToString(),
            await response.Content.ReadAsByteArrayAsync(cancellationToken).ConfigureAwait(false));
    }
}
