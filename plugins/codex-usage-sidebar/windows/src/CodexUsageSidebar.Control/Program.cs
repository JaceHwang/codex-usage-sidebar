using System.Text.Json;
using CodexUsageSidebar.Windows;

if (args.Length < 2 || !string.Equals(args[0], "probe", StringComparison.OrdinalIgnoreCase))
{
    Console.Error.WriteLine("Usage: CodexUsageSidebar.Control probe <absolute-output.json> [--include-text]");
    return 64;
}

var outputPath = Path.GetFullPath(args[1]);
if (!Path.IsPathFullyQualified(outputPath))
{
    Console.Error.WriteLine("The probe output path must be absolute.");
    return 64;
}

var includeText = args.Skip(2).Any(value => string.Equals(value, "--include-text", StringComparison.OrdinalIgnoreCase));
try
{
    var probe = new WindowsDiagnosticProbe(new Win32CodexWindowLocator());
    var report = await probe.CaptureAsync(includeText, CancellationToken.None);
    var temporaryPath = outputPath + ".tmp-" + Guid.NewGuid().ToString("N");
    Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
    await File.WriteAllTextAsync(
        temporaryPath,
        JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));
    File.Move(temporaryPath, outputPath, overwrite: true);
    Console.WriteLine(outputPath);
    return 0;
}
catch (Exception error)
{
    Console.Error.WriteLine(error.Message);
    return 70;
}
