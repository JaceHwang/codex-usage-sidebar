namespace CodexUsageSidebar.Core;

public sealed record CreditBalance(bool HasCredits, bool Unlimited, string? Balance);

public sealed record BankResetCredit(
    string? Status,
    DateTimeOffset? GrantedAt,
    DateTimeOffset? ExpiresAt,
    string? Title,
    string? Description);

public sealed record BankResetSummary(int AvailableCount, IReadOnlyList<BankResetCredit>? Credits);

public sealed record AllowanceSnapshot(
    double UsedPercent,
    int RemainingPercent,
    DateTimeOffset ResetsAt,
    DateTimeOffset ReceivedAt,
    int? WindowDurationMinutes = null,
    string? PlanType = null,
    CreditBalance? Credits = null,
    BankResetSummary? Bank = null)
{
    public AllowanceSnapshot MergeSupplementary(AllowanceSnapshot? previous) => previous is null
        ? this
        : this with
        {
            WindowDurationMinutes = WindowDurationMinutes ?? previous.WindowDurationMinutes,
            PlanType = PlanType ?? previous.PlanType,
            Credits = Credits ?? previous.Credits,
            Bank = Bank ?? previous.Bank,
        };
}

public enum RateLimitDecodingFailure
{
    InvalidJson,
    MissingCodexBucket,
    MissingUsedPercent,
    MissingResetTime,
    InvalidNumber,
}

public sealed class RateLimitDecodingException : Exception
{
    public RateLimitDecodingException(RateLimitDecodingFailure failure)
        : base(failure.ToString()) => Failure = failure;

    public RateLimitDecodingFailure Failure { get; }
}
