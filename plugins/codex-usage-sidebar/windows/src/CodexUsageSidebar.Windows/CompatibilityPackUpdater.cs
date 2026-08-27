using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace CodexUsageSidebar.Windows;

public enum CompatibilityPackUpdateResult { Updated, NotDue, NotModified, Rejected }

public sealed record CompatibilityPackResponse(int StatusCode, string? ETag, byte[] Content);
public sealed record CompatibilityPackCacheEntry(
    long Sequence,
    string? ETag,
    DateTimeOffset UpdatedAt,
    byte[] Catalog,
    byte[]? Manifest = null,
    byte[]? Signature = null);

public interface ICompatibilityPackTransport
{
    ValueTask<CompatibilityPackResponse> GetAsync(string? etag, CancellationToken cancellationToken);
}

public interface ICompatibilityPackCache
{
    ValueTask<CompatibilityPackCacheEntry?> LoadAsync(CancellationToken cancellationToken);
    ValueTask ReplaceAsync(CompatibilityPackCacheEntry entry, CancellationToken cancellationToken);
}

public sealed class CompatibilityPackUpdater(
    byte[] publicKey,
    ICompatibilityPackTransport transport,
    ICompatibilityPackCache cache,
    Func<DateTimeOffset> now)
{
    public const int MaximumPackBytes = 512 * 1024;
    private static readonly TimeSpan UpdateInterval = TimeSpan.FromHours(24);

    public async ValueTask<CompatibilityPackUpdateResult> UpdateAsync(CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(publicKey);
        ArgumentNullException.ThrowIfNull(transport);
        ArgumentNullException.ThrowIfNull(cache);
        ArgumentNullException.ThrowIfNull(now);
        var existing = await cache.LoadAsync(cancellationToken).ConfigureAwait(false);
        var observedAt = now();
        if (existing is not null && observedAt - existing.UpdatedAt < UpdateInterval)
        {
            return CompatibilityPackUpdateResult.NotDue;
        }

        var response = await transport.GetAsync(existing?.ETag, cancellationToken).ConfigureAwait(false);
        if (response.StatusCode == 304)
        {
            if (existing is not null)
            {
                await cache.ReplaceAsync(existing with { UpdatedAt = observedAt }, cancellationToken).ConfigureAwait(false);
            }
            return CompatibilityPackUpdateResult.NotModified;
        }
        if (response.StatusCode != 200 || response.Content is null || response.Content.Length > MaximumPackBytes)
        {
            return CompatibilityPackUpdateResult.Rejected;
        }
        if (!TryRead(response.Content, out var manifest, out var catalog, out var signature)
            || !TryValidateManifest(manifest, catalog, out var sequence, out var manifestEtag)
            || (existing is not null && sequence <= existing.Sequence)
            || !Verify(publicKey, manifest, catalog, signature))
        {
            return CompatibilityPackUpdateResult.Rejected;
        }

        await cache.ReplaceAsync(new CompatibilityPackCacheEntry(sequence, manifestEtag ?? response.ETag, observedAt, catalog, manifest, signature), cancellationToken)
            .ConfigureAwait(false);
        return CompatibilityPackUpdateResult.Updated;
    }

    public static byte[] SignaturePayload(byte[] manifest, byte[] catalog)
    {
        ArgumentNullException.ThrowIfNull(manifest);
        ArgumentNullException.ThrowIfNull(catalog);
        var payload = new byte[8 + manifest.Length + catalog.Length];
        BitConverter.GetBytes(manifest.Length).CopyTo(payload, 0);
        manifest.CopyTo(payload, 4);
        BitConverter.GetBytes(catalog.Length).CopyTo(payload, 4 + manifest.Length);
        catalog.CopyTo(payload, 8 + manifest.Length);
        return payload;
    }

    private static bool Verify(byte[] publicKey, byte[] manifest, byte[] catalog, byte[] signature)
    {
        try
        {
            using var verifier = ECDsa.Create();
            verifier.ImportSubjectPublicKeyInfo(publicKey, out _);
            return verifier.KeySize == 256 && verifier.VerifyData(SignaturePayload(manifest, catalog), signature, HashAlgorithmName.SHA256);
        }
        catch (CryptographicException) { return false; }
    }

    private static bool TryRead(byte[] pack, out byte[] manifest, out byte[] catalog, out byte[] signature)
    {
        manifest = catalog = signature = Array.Empty<byte>();
        try
        {
            using var stream = new MemoryStream(pack, writable: false);
            using var archive = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: false);
            if (archive.Entries.Count != 3) return false;
            long totalUncompressedBytes = 0;
            manifest = ReadExact(archive, "manifest.json", ref totalUncompressedBytes);
            catalog = ReadExact(archive, "selectors.json", ref totalUncompressedBytes);
            signature = ReadExact(archive, "signature.sig", ref totalUncompressedBytes);
            return manifest.Length > 0 && catalog.Length > 0 && catalog.Length <= SelectorProfileCatalog.MaximumCatalogBytes && signature.Length > 0;
        }
        catch (InvalidDataException) { return false; }
        catch (IOException) { return false; }
    }

    private static byte[] ReadExact(ZipArchive archive, string name, ref long totalUncompressedBytes)
    {
        var entry = archive.GetEntry(name) ?? throw new InvalidDataException();
        if (entry.Length > MaximumPackBytes || entry.CompressedLength > MaximumPackBytes
            || totalUncompressedBytes > MaximumPackBytes - entry.Length) throw new InvalidDataException();
        totalUncompressedBytes += entry.Length;
        using var input = entry.Open();
        using var output = new MemoryStream();
        input.CopyTo(output);
        if (output.Length != entry.Length || output.Length > MaximumPackBytes) throw new InvalidDataException();
        return output.ToArray();
    }

    private static bool TryValidateManifest(byte[] manifest, byte[] catalog, out long sequence, out string? etag)
    {
        sequence = 0;
        etag = null;
        try
        {
            using var document = JsonDocument.Parse(manifest);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object || root.EnumerateObject().Any(p => p.Name is not ("sequence" or "etag" or "catalogSha256"))
                || !root.TryGetProperty("sequence", out var value) || !value.TryGetInt64(out sequence) || sequence < 1
                || !root.TryGetProperty("catalogSha256", out var digest) || digest.ValueKind != JsonValueKind.String
                || !CryptographicOperations.FixedTimeEquals(Convert.FromHexString(digest.GetString() ?? string.Empty), SHA256.HashData(catalog))
                || !SelectorProfileCatalog.TryParse(Encoding.UTF8.GetString(catalog), out _)) return false;
            if (root.TryGetProperty("etag", out var configuredEtag))
            {
                if (configuredEtag.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(configuredEtag.GetString()) || configuredEtag.GetString()!.Length > 256) return false;
                etag = configuredEtag.GetString();
            }
            return true;
        }
        catch (JsonException) { return false; }
        catch (FormatException) { return false; }
    }
}

public sealed class CompatibilityPackFileCache(string directory) : ICompatibilityPackCache
{
    private const string CacheName = "compatibility-pack.json";

    public async ValueTask<CompatibilityPackCacheEntry?> LoadAsync(CancellationToken cancellationToken)
    {
        var path = Path.Combine(directory, CacheName);
        if (!File.Exists(path)) return null;
        await using var stream = File.OpenRead(path);
        var entry = await JsonSerializer.DeserializeAsync<CompatibilityPackDiskEntry>(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
        return entry is null || entry.Catalog.Length > SelectorProfileCatalog.MaximumCatalogBytes
            || !SelectorProfileCatalog.TryParse(Encoding.UTF8.GetString(entry.Catalog), out _)
            ? null : new CompatibilityPackCacheEntry(entry.Sequence, entry.ETag, entry.UpdatedAt, entry.Catalog, entry.Manifest, entry.Signature);
    }

    public async ValueTask ReplaceAsync(CompatibilityPackCacheEntry entry, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(directory);
        var destination = Path.Combine(directory, CacheName);
        var temporary = destination + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            await File.WriteAllTextAsync(temporary, JsonSerializer.Serialize(new CompatibilityPackDiskEntry(entry.Sequence, entry.ETag, entry.UpdatedAt, entry.Catalog, entry.Manifest, entry.Signature)), cancellationToken).ConfigureAwait(false);
            File.Move(temporary, destination, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    private sealed record CompatibilityPackDiskEntry(long Sequence, string? ETag, DateTimeOffset UpdatedAt, byte[] Catalog, byte[]? Manifest, byte[]? Signature);
}
