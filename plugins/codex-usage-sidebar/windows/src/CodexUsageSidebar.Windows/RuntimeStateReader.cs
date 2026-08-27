using System.Text.Json;
using System.Text.Json.Serialization;

namespace CodexUsageSidebar.Windows;

public static class RuntimeStateReader
{
    private static readonly JsonSerializerOptions Options = new() { Converters = { new JsonStringEnumConverter() } };

    public static async ValueTask<RuntimeStateOutcome?> LoadAsync(string path, CancellationToken cancellationToken)
    {
        if (!File.Exists(path)) return null;
        try
        {
            await using var stream = File.OpenRead(path);
            return await JsonSerializer.DeserializeAsync<RuntimeStateOutcome>(stream, Options, cancellationToken).ConfigureAwait(false);
        }
        catch (JsonException) { return null; }
        catch (IOException) { return null; }
        catch (UnauthorizedAccessException) { return null; }
    }
}
