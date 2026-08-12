namespace CodexUsageSidebar.Windows;

public static class UiaSemanticRoles
{
    public const string None = "";
    public const string OpenLocation = "OpenLocation";
}

public static class UiaSemanticRoleClassifier
{
    private static readonly string[] ExactNames = ["打开位置", "開啟位置", "Open Location"];

    public static IReadOnlyList<string> SupportedExactNames => ExactNames;

    public static string Classify(string? name)
    {
        var normalized = (name ?? string.Empty)
            .Trim()
            .Replace("-", " ", StringComparison.Ordinal)
            .Replace("_", " ", StringComparison.Ordinal)
            .ToLowerInvariant();
        return normalized.Contains("打开位置", StringComparison.Ordinal)
            || normalized.Contains("開啟位置", StringComparison.Ordinal)
            || normalized.Contains("open location", StringComparison.Ordinal)
            || normalized.Contains("openlocation", StringComparison.Ordinal)
                ? UiaSemanticRoles.OpenLocation
                : UiaSemanticRoles.None;
    }
}
