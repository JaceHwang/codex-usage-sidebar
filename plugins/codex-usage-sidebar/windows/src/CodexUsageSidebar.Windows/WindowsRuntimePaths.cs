namespace CodexUsageSidebar.Windows;

public sealed record WindowsRuntimePaths(
    string CodexExecutable,
    string IsolatedCodexHome)
{
    public static WindowsRuntimePaths Create(string payloadDirectory, string localAppData)
    {
        RequireAbsoluteWindowsPath(payloadDirectory, nameof(payloadDirectory));
        RequireAbsoluteWindowsPath(localAppData, nameof(localAppData));
        return new WindowsRuntimePaths(
            Path.Combine(payloadDirectory.TrimEnd((char)0x5c, '/'), "codex.exe"),
            Path.Combine(
                localAppData.TrimEnd((char)0x5c, '/'),
                "CodexUsageSidebar",
                "CodexHome"));
    }

    private static void RequireAbsoluteWindowsPath(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value)
            || value.Length < 3
            || !char.IsAsciiLetter(value[0])
            || value[1] != ':'
            || value[2] is not ('\\' or '/')
            || value.IndexOfAny(['\0', '"']) >= 0)
        {
            throw new ArgumentException("An absolute Windows path is required.", parameterName);
        }
    }
}
