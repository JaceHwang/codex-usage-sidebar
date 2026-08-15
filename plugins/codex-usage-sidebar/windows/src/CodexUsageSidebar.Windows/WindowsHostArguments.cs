namespace CodexUsageSidebar.Windows;

public sealed record WindowsHostArguments(
    bool Background,
    string? PluginRoot,
    string? PluginData)
{
    public static WindowsHostArguments? TryParse(IReadOnlyList<string> args)
    {
        var background = false;
        string? pluginRoot = null;
        string? pluginData = null;

        for (var index = 0; index < args.Count; index++)
        {
            switch (args[index])
            {
                case "--background" when !background:
                    background = true;
                    break;
                case "--plugin-root" when pluginRoot is null:
                    if (!TryReadAbsolutePath(args, ref index, out pluginRoot)) return null;
                    break;
                case "--plugin-data" when pluginData is null:
                    if (!TryReadAbsolutePath(args, ref index, out pluginData)) return null;
                    break;
                default:
                    return null;
            }
        }

        return new WindowsHostArguments(background, pluginRoot, pluginData);
    }

    private static bool TryReadAbsolutePath(
        IReadOnlyList<string> args,
        ref int index,
        out string? path)
    {
        path = null;
        if (++index >= args.Count || !Path.IsPathFullyQualified(args[index])) return false;
        path = Path.GetFullPath(args[index]);
        return true;
    }
}
