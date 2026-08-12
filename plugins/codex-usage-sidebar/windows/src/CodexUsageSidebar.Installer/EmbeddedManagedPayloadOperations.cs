namespace CodexUsageSidebar.Installer;

public sealed class EmbeddedManagedPayloadOperations(
    EmbeddedPayloadSource source,
    EmbeddedReleaseInstallerPlan plan) : IManagedPayloadOperations
{
    public void Validate()
    {
        using var payload = source.Extract(plan.PrivateStageParent);
        AtomicPayloadInstaller.ValidateManifest(payload.PayloadDirectory, plan.TrustedIdentity);
    }

    public void Activate()
    {
        using var payload = source.Extract(plan.PrivateStageParent);
        new AtomicPayloadInstaller(plan.TrustedIdentity)
            .Install(payload.PayloadDirectory, plan.Paths.CurrentPayload);
    }

    public void RemoveCurrent()
    {
        SafeUninstallGuard.EnsureExactPayload(plan.Paths, plan.Paths.CurrentPayload);
        if (!Directory.Exists(plan.Paths.CurrentPayload)) return;
        AtomicPayloadInstaller.ValidateNoLinks(plan.Paths.CurrentPayload);

        var tombstone = Path.Combine(
            plan.Paths.InstallRoot,
            ".cus-uninstall-" + Guid.NewGuid().ToString("N"));
        Directory.Move(plan.Paths.CurrentPayload, tombstone);
        try
        {
            Directory.Delete(tombstone, recursive: true);
        }
        catch
        {
            if (Directory.Exists(tombstone) && !Directory.Exists(plan.Paths.CurrentPayload))
            {
                Directory.Move(tombstone, plan.Paths.CurrentPayload);
            }
            throw;
        }
    }
}
