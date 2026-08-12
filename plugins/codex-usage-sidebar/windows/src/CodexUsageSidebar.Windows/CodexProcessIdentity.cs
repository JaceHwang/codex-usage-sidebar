namespace CodexUsageSidebar.Windows;

internal static class CodexProcessIdentity
{
    internal static bool IsSupported(
        string processName,
        string? productName,
        string? companyName,
        string? executablePath = null,
        string? installedApplicationsRoot = null)
    {
        if (!string.Equals(processName, "ChatGPT", StringComparison.OrdinalIgnoreCase)
            || !string.Equals(productName, "Codex", StringComparison.Ordinal)
            || !string.Equals(companyName, "OpenAI OpCo, LLC", StringComparison.Ordinal))
        {
            return false;
        }
        if (string.IsNullOrWhiteSpace(executablePath)
            || string.IsNullOrWhiteSpace(installedApplicationsRoot))
        {
            return false;
        }

        var root = Path.GetFullPath(installedApplicationsRoot)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        var candidate = Path.GetFullPath(executablePath);
        if (!candidate.StartsWith(root, StringComparison.OrdinalIgnoreCase)) return false;

        var relative = candidate[root.Length..].Replace('/', '\\');
        var separators = relative.Split('\\', StringSplitOptions.RemoveEmptyEntries);
        return separators.Length == 3
            && separators[0].StartsWith("OpenAI.Codex_", StringComparison.OrdinalIgnoreCase)
            && string.Equals(separators[1], "app", StringComparison.OrdinalIgnoreCase)
            && string.Equals(separators[2], "ChatGPT.exe", StringComparison.OrdinalIgnoreCase);
    }
}
