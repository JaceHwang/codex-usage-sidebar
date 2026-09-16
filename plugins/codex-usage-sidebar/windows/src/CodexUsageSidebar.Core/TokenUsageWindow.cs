namespace CodexUsageSidebar.Core;

public sealed record TokenUsageCycle(DateOnly FirstDay, IReadOnlyDictionary<DateOnly, long> TokensByDay,
    long Total, TokenUsageAvailability Availability);

public static class TokenUsageWindow
{
    public static QuotaWindowSnapshot Select(AllowanceSnapshot snapshot) =>
        snapshot.Secondary is { } secondary &&
        (secondary.WindowDurationMinutes ?? 0) > (snapshot.WindowDurationMinutes ?? 0)
            ? secondary
            : new(snapshot.UsedPercent, snapshot.RemainingPercent, snapshot.ResetsAt, snapshot.WindowDurationMinutes);

    public static TokenUsageCycle Resolve(AllowanceSnapshot allowance, TokenUsageSnapshot usage,
        DateTimeOffset now, TimeZoneInfo timeZone)
    {
        var window = Select(allowance);
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(now, timeZone).DateTime);
        if (window.WindowDurationMinutes is not > 0)
            return new(today.AddDays(-6), new Dictionary<DateOnly, long>(), 0,
                usage.Availability == TokenUsageAvailability.Available ? TokenUsageAvailability.Unavailable : usage.Availability);
        DateOnly start;
        try
        {
            start = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                window.ResetsAt.AddMinutes(-window.WindowDurationMinutes.Value), timeZone).DateTime);
        }
        catch (ArgumentOutOfRangeException)
        {
            return new(today.AddDays(-6), new Dictionary<DateOnly, long>(), 0, TokenUsageAvailability.Unavailable);
        }
        if (usage.Availability != TokenUsageAvailability.Available)
            return new(start, new Dictionary<DateOnly, long>(), 0, usage.Availability);
        var last = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
            now < window.ResetsAt ? now : window.ResetsAt, timeZone).DateTime);
        var buckets = new Dictionary<DateOnly, long>();
        long total = 0;
        try
        {
            foreach (var bucket in usage.DailyBuckets)
            {
                if (bucket.Date < start || bucket.Date > last) continue;
                if (bucket.Tokens < 0) throw new OverflowException();
                buckets[bucket.Date] = checked(buckets.GetValueOrDefault(bucket.Date) + bucket.Tokens);
                total = checked(total + bucket.Tokens);
            }
        }
        catch (OverflowException)
        {
            return new(start, new Dictionary<DateOnly, long>(), 0, TokenUsageAvailability.Unavailable);
        }
        return new(start, buckets, total, TokenUsageAvailability.Available);
    }
}
