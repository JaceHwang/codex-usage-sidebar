using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed record WindowsProbeReport(
    string SchemaVersion,
    DateTimeOffset CapturedAt,
    string OsVersion,
    bool IncludesText,
    WindowsProbeHost Host,
    string? ExecutablePathToken,
    IReadOnlyList<UiaProbeNode> Nodes,
    TitlebarSnapshot? Titlebar);

public sealed record WindowsProbeHost(
    RectD Bounds,
    bool IsForeground,
    double DpiScale,
    string BuildIdentity)
{
    public static WindowsProbeHost From(HostWindowSnapshot host) => new(
        host.Bounds,
        host.IsForeground,
        host.DpiScale,
        host.BuildIdentity);
}

public sealed record UiaProbeNode(
    int Depth,
    string ControlType,
    string AutomationId,
    string ClassName,
    RectD Bounds,
    int NameLength,
    string NameToken,
    string SemanticRole,
    string? Name);
