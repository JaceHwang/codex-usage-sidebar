using System.Diagnostics;
using System.Runtime.InteropServices;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class ProcessJsonLineConnectionTests
{
    [TestMethod]
    public async Task DrainsLargeStandardErrorWhileReadingStandardOutput()
    {
        var runtimeVersion = new DirectoryInfo(RuntimeEnvironment.GetRuntimeDirectory().TrimEnd(Path.DirectorySeparatorChar));
        var dotnetRoot = runtimeVersion.Parent!.Parent!.Parent!;
        var dotnetHost = Path.Combine(dotnetRoot.FullName, OperatingSystem.IsWindows() ? "dotnet.exe" : "dotnet");
        var fixtureAssembly = typeof(ProcessFixtureMarker).Assembly.Location;
        var startInfo = new ProcessStartInfo
        {
            FileName = dotnetHost,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        startInfo.ArgumentList.Add(fixtureAssembly);
        startInfo.ArgumentList.Add("stderr-flood");
        var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Fixture did not start.");
        await using var connection = new ProcessJsonLineConnection(process);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        string? observed = null;

        await foreach (var line in connection.ReadLinesAsync(timeout.Token))
        {
            observed = line;
            break;
        }

        Assert.AreEqual("ready", observed);
        Assert.IsTrue(connection.StandardErrorWasTruncated);
        Assert.AreEqual(4_000, connection.StandardErrorTail.Length);
        Assert.IsTrue(connection.StandardErrorTail.All(character => character == 'e'));
    }
}
