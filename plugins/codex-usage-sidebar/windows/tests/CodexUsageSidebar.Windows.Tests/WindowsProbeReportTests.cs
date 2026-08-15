using System.Text.Json;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class WindowsProbeReportTests
{
    [TestMethod]
    public void SerializesHostWithoutRawWindowHandle()
    {
        var host = new HostWindowSnapshot(
            new IntPtr(1234),
            new RectD(10, 20, 1200, 800),
            true,
            1.5,
            "151.0.7922.76");
        var report = new WindowsProbeReport(
            "1",
            new DateTimeOffset(2026, 8, 12, 0, 0, 0, TimeSpan.Zero),
            "Windows",
            false,
            WindowsProbeHost.From(host),
            "path-token",
            [],
            new TitlebarSnapshot(
                1363,
                [new RectD(1363, -1, 137, 36)],
                new RectD(500, 70, 1000, 92)));

        using var document = JsonDocument.Parse(JsonSerializer.Serialize(report));
        var serializedHost = document.RootElement.GetProperty("Host");

        Assert.IsFalse(serializedHost.TryGetProperty("Handle", out _));
        Assert.AreEqual(1200, serializedHost.GetProperty("Bounds").GetProperty("Width").GetDouble());
        Assert.IsTrue(serializedHost.GetProperty("IsForeground").GetBoolean());
        Assert.AreEqual(1.5, serializedHost.GetProperty("DpiScale").GetDouble());
        Assert.AreEqual("151.0.7922.76", serializedHost.GetProperty("BuildIdentity").GetString());
        Assert.AreEqual(
            1363,
            document.RootElement.GetProperty("Titlebar").GetProperty("PreferredAnchorTrailingEdge").GetDouble());
        Assert.AreEqual(
            70,
            document.RootElement.GetProperty("Titlebar").GetProperty("ToolbarBounds").GetProperty("Y").GetDouble());
    }
}
