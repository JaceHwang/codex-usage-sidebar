using System.Text.Json;

namespace CodexUsageSidebar.Installer;

public sealed class RuntimeStateInstallerHealthSource(string path) : IInstallerRuntimeHealthSource
{
    public async Task<InstallerRuntimeHealth> WaitAsync(TimeSpan timeout, CancellationToken cancellationToken)
    {
        var deadline = DateTimeOffset.UtcNow + timeout;
        while (DateTimeOffset.UtcNow < deadline)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var health = await TryReadAsync(cancellationToken).ConfigureAwait(false);
            if (health is not null) return health.Value;
            await Task.Delay(TimeSpan.FromMilliseconds(100), cancellationToken).ConfigureAwait(false);
        }
        return InstallerRuntimeHealth.InstallRequired;
    }

    private async Task<InstallerRuntimeHealth?> TryReadAsync(CancellationToken cancellationToken)
    {
        try
        {
            await using var stream = File.OpenRead(path);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
            var root = document.RootElement;
            if (root.TryGetProperty("RuntimeState", out var state) && state.GetString() == "DeviceValidationRequired")
                return InstallerRuntimeHealth.ValidationNeeded;
            if (root.TryGetProperty("RuntimeState", out state) && state.GetString() == "Visible"
                && root.TryGetProperty("Decision", out var decision)
                && decision.TryGetProperty("Placement", out var placement))
                return placement.GetString() == "Fallback" ? InstallerRuntimeHealth.SafeDockVisible : InstallerRuntimeHealth.Healthy;
        }
        catch (IOException) { }
        catch (JsonException) { }
        catch (UnauthorizedAccessException) { }
        return null;
    }
}
