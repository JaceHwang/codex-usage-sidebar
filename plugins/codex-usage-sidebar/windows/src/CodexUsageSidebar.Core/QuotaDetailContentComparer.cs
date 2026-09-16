namespace CodexUsageSidebar.Core;

public static class QuotaDetailContentComparer
{
    public static bool Equivalent(QuotaDetailContent? previous, QuotaDetailContent current)
    {
        if (previous is null || !previous.Rows.SequenceEqual(current.Rows)
            || !(previous.QuotaWindows ?? []).SequenceEqual(current.QuotaWindows ?? [])) return false;
        if (previous.TokenUsage is { } oldTokens && current.TokenUsage is { } newTokens)
        {
            if (!oldTokens.Days.SequenceEqual(newTokens.Days)
                || oldTokens with { Days = newTokens.Days } != newTokens) return false;
        }
        else if (previous.TokenUsage != current.TokenUsage) return false;
        // Lists need structural comparison above; all remaining record fields
        // retain value equality, including account identity and product version.
        return previous with { Rows = current.Rows, QuotaWindows = current.QuotaWindows,
            TokenUsage = current.TokenUsage } == current;
    }
}
