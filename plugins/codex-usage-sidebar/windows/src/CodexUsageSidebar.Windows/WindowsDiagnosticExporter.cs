using System.IO.Compression;
using System.Text.Json;

namespace CodexUsageSidebar.Windows;

public static class WindowsDiagnosticExporter
{
    public static async ValueTask ExportAsync(string destination, WindowsProbeReport report, RuntimeStateOutcome? state, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(destination);
        ArgumentNullException.ThrowIfNull(report);
        var fullDestination = Path.GetFullPath(destination);
        var directory = Path.GetDirectoryName(fullDestination) ?? throw new ArgumentException("The diagnostic destination must include a directory.", nameof(destination));
        Directory.CreateDirectory(directory);
        var temporary = fullDestination + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            using (var archive = ZipFile.Open(temporary, ZipArchiveMode.Create))
            {
                var sanitized = report with { IncludesText = false, ExecutablePathToken = null, Nodes = report.Nodes.Select(node => node with { Name = null }).ToArray() };
                await WriteAsync(archive, "report.json", sanitized, cancellationToken).ConfigureAwait(false);
                await WriteAsync(archive, "summary.json", new { runtimeState = state?.RuntimeState.ToString() ?? "unknown", placement = state?.Decision.Placement.ToString() ?? "unknown", reason = state?.Decision.FailureCode.ToString() ?? "unknown" }, cancellationToken).ConfigureAwait(false);
            }
            File.Move(temporary, fullDestination, overwrite: true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    private static async ValueTask WriteAsync(ZipArchive archive, string name, object value, CancellationToken cancellationToken)
    {
        var entry = archive.CreateEntry(name, CompressionLevel.Optimal);
        await using var stream = entry.Open();
        await JsonSerializer.SerializeAsync(stream, value, cancellationToken: cancellationToken).ConfigureAwait(false);
    }
}
