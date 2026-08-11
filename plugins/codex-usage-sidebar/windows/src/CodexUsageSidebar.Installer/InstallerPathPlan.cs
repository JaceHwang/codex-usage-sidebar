namespace CodexUsageSidebar.Installer;

public sealed record InstallerPathPlan(
    string InstallRoot,
    string CurrentPayload,
    string IsolatedCodexHome,
    string StateDirectory)
{
    public static InstallerPathPlan Create(string localAppData)
    {
        var root = WindowsPath.Normalize(localAppData);
        var installRoot = WindowsPath.Combine(root, "CodexUsageSidebar");
        return new InstallerPathPlan(
            installRoot,
            WindowsPath.Combine(installRoot, "Current"),
            WindowsPath.Combine(installRoot, "CodexHome"),
            WindowsPath.Combine(installRoot, "State"));
    }

    public bool IsExactCurrentPayload(string candidate) =>
        string.Equals(CurrentPayload, WindowsPath.Normalize(candidate), StringComparison.OrdinalIgnoreCase);
}

internal static class WindowsPath
{
    public static string Combine(string root, string component)
    {
        if (string.IsNullOrWhiteSpace(component)
            || component.Contains('\\')
            || component.Contains('/')
            || component is "." or "..")
        {
            throw new ArgumentException("A single safe path component is required.", nameof(component));
        }
        return Normalize(root.TrimEnd('\\') + "\\" + component);
    }

    public static string Normalize(string value)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value);
        var path = value.Trim().Replace('/', '\\');
        if (path.IndexOfAny(['\0', '"', '<', '>', '|', '*', '?']) >= 0)
        {
            throw new ArgumentException("The path contains invalid Windows characters.", nameof(value));
        }

        string root;
        string remainder;
        if (path.Length >= 3 && char.IsAsciiLetter(path[0]) && path[1] == ':' && path[2] == '\\')
        {
            root = char.ToUpperInvariant(path[0]) + @":\";
            remainder = path[3..];
        }
        else if (path.StartsWith(@"\\", StringComparison.Ordinal))
        {
            var unc = path[2..].Split('\\', StringSplitOptions.RemoveEmptyEntries);
            if (unc.Length < 2)
            {
                throw new ArgumentException("A UNC path must include a server and share.", nameof(value));
            }
            root = @"\\" + unc[0] + @"\" + unc[1] + @"\";
            remainder = string.Join('\\', unc.Skip(2));
        }
        else
        {
            throw new ArgumentException("An absolute Windows path is required.", nameof(value));
        }

        var segments = new List<string>();
        foreach (var segment in remainder.Split('\\', StringSplitOptions.RemoveEmptyEntries))
        {
            if (segment == ".") continue;
            if (segment == "..")
            {
                if (segments.Count == 0)
                {
                    throw new ArgumentException("The path escapes its root.", nameof(value));
                }
                segments.RemoveAt(segments.Count - 1);
                continue;
            }
            if (segment.EndsWith(' ') || segment.EndsWith('.'))
            {
                throw new ArgumentException("Windows path components cannot end in a space or dot.", nameof(value));
            }
            segments.Add(segment);
        }
        return segments.Count == 0 ? root : root + string.Join('\\', segments);
    }
}
