namespace CodexUsageSidebar.Installer;

public static class EmbeddedReleaseVerificationCommand
{
    public static bool TryRun(
        InstallerPayloadMode payloadMode,
        IReadOnlyList<string> arguments,
        Action verify)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        ArgumentNullException.ThrowIfNull(verify);
        if (arguments.Count == 0
            || !string.Equals(arguments[0], "--verify-embedded", StringComparison.Ordinal))
        {
            return false;
        }
        if (payloadMode != InstallerPayloadMode.EmbeddedRelease || arguments.Count != 1)
        {
            throw new ArgumentException(
                "Embedded verification is available only as an exact release-installer command.",
                nameof(arguments));
        }
        verify();
        return true;
    }
}

public static class EmbeddedReleaseActivationDiagnosticCommand
{
    public static bool TryRun(
        InstallerPayloadMode payloadMode,
        IReadOnlyList<string> arguments,
        Action diagnose)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        ArgumentNullException.ThrowIfNull(diagnose);
        if (arguments.Count == 0
            || !string.Equals(arguments[0], "--diagnose-embedded-activation", StringComparison.Ordinal))
        {
            return false;
        }
        if (payloadMode != InstallerPayloadMode.EmbeddedRelease || arguments.Count != 1)
        {
            throw new ArgumentException(
                "Embedded activation diagnostics are available only as an exact release-installer command.",
                nameof(arguments));
        }
        diagnose();
        return true;
    }
}
