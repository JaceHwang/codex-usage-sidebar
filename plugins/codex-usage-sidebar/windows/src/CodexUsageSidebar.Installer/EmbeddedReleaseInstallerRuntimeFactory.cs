using System.Reflection;

namespace CodexUsageSidebar.Installer;

public sealed record EmbeddedReleaseInstallerMetadata(
    string Version,
    string SourceCommit,
    string PayloadManifestSha256,
    string CodexRuntimeSource,
    string CodexRuntimeSha256)
{
    public const string VersionKey = "EmbeddedPayloadVersion";
    public const string SourceCommitKey = "EmbeddedSourceCommit";
    public const string PayloadManifestSha256Key = "EmbeddedPayloadManifestSha256";
    public const string CodexRuntimeSourceKey = "EmbeddedCodexRuntimeSource";
    public const string CodexRuntimeSha256Key = "EmbeddedCodexRuntimeSha256";

    public static EmbeddedReleaseInstallerMetadata? TryCreate(
        IReadOnlyDictionary<string, string?> metadata)
    {
        ArgumentNullException.ThrowIfNull(metadata);
        var values = new[]
        {
            metadata.GetValueOrDefault(VersionKey),
            metadata.GetValueOrDefault(SourceCommitKey),
            metadata.GetValueOrDefault(PayloadManifestSha256Key),
            metadata.GetValueOrDefault(CodexRuntimeSourceKey),
            metadata.GetValueOrDefault(CodexRuntimeSha256Key),
        };
        if (values.Any(string.IsNullOrWhiteSpace)) return null;
        return new EmbeddedReleaseInstallerMetadata(
            values[0]!, values[1]!, values[2]!, values[3]!, values[4]!);
    }
}

public static class EmbeddedReleaseInstallerRuntimeFactory
{
    public const string PayloadResourcePrefix = "CodexUsageSidebar.Payload.";

    public static IInstallerUiActions? TryCreate(
        Assembly assembly,
        IReadOnlyDictionary<string, string?> assemblyMetadata,
        string localAppData,
        string architecture,
        int windowsBuild)
    {
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("The embedded release installer requires Windows 11.");
        }
        var bundle = TryCreateBundle(
            assembly, assemblyMetadata, localAppData, architecture, windowsBuild);
        if (bundle is null) return null;
        var (plan, source) = bundle.Value;
        var autostartPlan = AutostartPlan.Create(plan.ManagedHostExecutable);
        return new DeviceTestInstallerUiActions(
            plan.Paths,
            new FileManagedInstallLock(plan.Paths.InstallRoot),
            new EmbeddedManagedPayloadOperations(source, plan),
            new ManagedAutostart(autostartPlan, new WindowsCurrentUserRunStore()),
            new ManagedHostLifecycle(plan.ManagedHostExecutable, new WindowsManagedProcessCatalog()));
    }

    public static void VerifyEmbeddedPayload(
        Assembly assembly,
        IReadOnlyDictionary<string, string?> assemblyMetadata,
        string localAppData,
        string architecture,
        int windowsBuild)
    {
        var bundle = TryCreateBundle(
            assembly, assemblyMetadata, localAppData, architecture, windowsBuild)
            ?? throw new InvalidOperationException(
                "The release installer is missing embedded payload trust metadata.");
        new EmbeddedManagedPayloadOperations(bundle.Source, bundle.Plan).Validate();
    }

    public static EmbeddedActivationDiagnosticResult DiagnoseEmbeddedActivation(
        Assembly assembly,
        IReadOnlyDictionary<string, string?> assemblyMetadata,
        string architecture,
        int windowsBuild)
    {
        var diagnosticRoot = Path.Combine(
            Path.GetTempPath(),
            "CodexUsageSidebarActivationDiagnostic-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(diagnosticRoot);
        try
        {
            var bundle = TryCreateBundle(
                assembly, assemblyMetadata, diagnosticRoot, architecture, windowsBuild)
                ?? throw new InvalidOperationException(
                    "The release installer is missing embedded payload trust metadata.");
            return EmbeddedActivationDiagnostic.Run(bundle.Source, bundle.Plan);
        }
        finally
        {
            if (Directory.Exists(diagnosticRoot)) Directory.Delete(diagnosticRoot, recursive: true);
        }
    }

    private static (EmbeddedReleaseInstallerPlan Plan, EmbeddedPayloadSource Source)? TryCreateBundle(
        Assembly assembly,
        IReadOnlyDictionary<string, string?> assemblyMetadata,
        string localAppData,
        string architecture,
        int windowsBuild)
    {
        var metadata = EmbeddedReleaseInstallerMetadata.TryCreate(assemblyMetadata);
        if (metadata is null) return null;
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("The embedded release installer requires Windows 11.");
        }
        var plan = EmbeddedReleaseInstallerPlan.Create(
            localAppData,
            architecture,
            windowsBuild,
            metadata.Version,
            metadata.SourceCommit,
            metadata.PayloadManifestSha256,
            metadata.CodexRuntimeSource,
            metadata.CodexRuntimeSha256);
        var source = EmbeddedPayloadSource.FromAssembly(
            assembly,
            PayloadResourcePrefix,
            metadata.PayloadManifestSha256);
        return (plan, source);
    }
}
