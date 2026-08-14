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
        EmbeddedPayloadLease? payload = null;
        Exception? activationFailure = null;
        try
        {
            try
            {
                payload = source.Extract(plan.PrivateStageParent);
            }
            catch (Exception error)
            {
                throw new InstallerSafeStageException("embedded-extract", error);
            }

            new AtomicPayloadInstaller(plan.TrustedIdentity, reportSafeStages: true)
                .Install(payload.PayloadDirectory, plan.Paths.CurrentPayload);
        }
        catch (Exception error)
        {
            activationFailure = error;
            if (error is InstallerSafeStageException) throw;
            throw new InstallerSafeStageException("atomic-install", error);
        }
        finally
        {
            if (payload is not null)
            {
                try
                {
                    payload.Dispose();
                }
                catch (Exception) when (activationFailure is not null)
                {
                    // Preserve the already classified activation failure for the caller.
                }
                catch (Exception error)
                {
                    throw new InstallerSafeStageException("embedded-cleanup", error);
                }
            }
        }
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
