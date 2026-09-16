using System.Text.Json;
using System.Text.Json.Serialization;

namespace CodexUsageSidebar.Core;

public sealed class IndicatorPreferencesStore(string path)
{
    private static readonly JsonSerializerOptions Options = new()
    {
        Converters = { new JsonStringEnumConverter() },
    };
    private readonly SemaphoreSlim writes = new(1, 1);

    public async Task<IndicatorPlacementPreferences> LoadAsync(CancellationToken cancellationToken)
    {
        try
        {
            await using var file = File.OpenRead(path);
            var value = await JsonSerializer.DeserializeAsync<IndicatorPlacementPreferences>(file, Options, cancellationToken).ConfigureAwait(false);
            if (value is null || !Enum.IsDefined(value.Mode) || value.Placements is null
                || value.Placements.Values.Any(p => p is null || !double.IsFinite(p.NormalizedX) || !double.IsFinite(p.NormalizedY)))
                return new();
            return value;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        {
            // Preserve malformed files for diagnostics; do not overwrite them on load.
            return new();
        }
    }

    public async Task SaveAsync(IndicatorPlacementPreferences preferences, CancellationToken cancellationToken)
    {
        // Snapshot before awaiting so later pointer/menu events cannot change a pending write.
        var bytes = JsonSerializer.SerializeToUtf8Bytes(preferences, Options);
        await writes.WaitAsync(cancellationToken).ConfigureAwait(false);
        string? temporaryPath = null;
        try
        {
            var directory = Path.GetDirectoryName(Path.GetFullPath(path))!;
            Directory.CreateDirectory(directory);
            temporaryPath = Path.Combine(directory, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
            await File.WriteAllBytesAsync(temporaryPath, bytes, cancellationToken).ConfigureAwait(false);
            File.Move(temporaryPath, path, overwrite: true);
        }
        finally
        {
            if (temporaryPath is not null && File.Exists(temporaryPath)) File.Delete(temporaryPath);
            writes.Release();
        }
    }
}
