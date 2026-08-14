namespace CodexUsageSidebar.Installer;

public sealed record EmbeddedActivationDiagnosticResult(IReadOnlyList<string> CompletedStages);

public sealed class EmbeddedActivationDiagnosticException(string stage, Exception innerException)
    : Exception($"Embedded activation diagnostic failed at stage: {stage}.", innerException)
{
    public string Stage { get; } = stage;
}

public static class EmbeddedActivationDiagnostic
{
    public static EmbeddedActivationDiagnosticResult Run(
        EmbeddedPayloadSource source,
        EmbeddedReleaseInstallerPlan plan)
    {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentNullException.ThrowIfNull(plan);

        var completed = new List<string>();
        IDisposable? operationLock = null;
        EmbeddedPayloadLease? payload = null;
        EmbeddedActivationDiagnosticException? failure = null;
        try
        {
            try
            {
                operationLock = new FileManagedInstallLock(plan.Paths.InstallRoot).Acquire();
            }
            catch (Exception error)
            {
                failure = new EmbeddedActivationDiagnosticException("operation-lock", error);
                throw failure;
            }
            completed.Add("operation-lock");
            try
            {
                payload = source.Extract(plan.PrivateStageParent);
            }
            catch (Exception error)
            {
                failure = new EmbeddedActivationDiagnosticException("embedded-extract", error);
                throw failure;
            }
            completed.Add("embedded-extract");
            try
            {
                new AtomicPayloadInstaller(plan.TrustedIdentity)
                    .Install(payload.PayloadDirectory, plan.Paths.CurrentPayload);
            }
            catch (Exception error)
            {
                failure = new EmbeddedActivationDiagnosticException("atomic-install", error);
                throw failure;
            }
            completed.Add("atomic-install");
        }
        finally
        {
            if (payload is not null)
            {
                try
                {
                    payload.Dispose();
                    completed.Add("embedded-cleanup");
                }
                catch (Exception error)
                {
                    if (failure is null)
                    {
                        failure = new EmbeddedActivationDiagnosticException("embedded-cleanup", error);
                    }
                }
            }
            if (operationLock is not null)
            {
                try
                {
                    operationLock.Dispose();
                    completed.Add("operation-lock-cleanup");
                }
                catch (Exception error)
                {
                    if (failure is null)
                    {
                        failure = new EmbeddedActivationDiagnosticException("operation-lock-cleanup", error);
                    }
                }
            }
        }
        if (failure is not null) throw failure;
        return new EmbeddedActivationDiagnosticResult(completed);
    }
}
