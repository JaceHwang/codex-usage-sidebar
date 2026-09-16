namespace CodexUsageSidebar.Core;

public sealed record QuotaDetailRow(string Label, string Value,
    bool EmphasizeCountdown = false, int? AccentRemainingPercent = null);

public sealed record QuotaWindowPresentation(string Label, int RemainingPercent);
public sealed record QuotaIndicatorRow(string Label, int RemainingPercent, string Reset)
{
    public string Percentage => $"{RemainingPercent}%";
}

public sealed record QuotaIndicatorSummary(
    string Primary,
    string? Secondary,
    int PrimaryRemainingPercent,
    int? SecondaryRemainingPercent);

public sealed record QuotaTokenUsageDay(
    DateOnly Date,
    string DateLabel,
    string TokensLabel,
    long Tokens,
    bool IsCurrent);

public sealed record QuotaTokenUsageContent(
    string Title,
    TokenUsageAvailability Availability,
    IReadOnlyList<QuotaTokenUsageDay> Days,
    long CurrentPeriodTotal,
    string TotalLabel,
    string UnavailableLabel,
    string? DelayLabel);

public sealed record QuotaDetailContent(
    string Title,
    int RemainingPercent,
    IReadOnlyList<QuotaDetailRow> Rows,
    QuotaTokenUsageContent? TokenUsage = null,
    AccountIdentity? Account = null,
    string Version = "",
    string AccountLabel = "Account",
    IReadOnlyList<QuotaWindowPresentation>? QuotaWindows = null);

public static class QuotaDetailFormatter
{
    public static string ProductVersion { get; } =
        System.Reflection.CustomAttributeExtensions.GetCustomAttribute<System.Reflection.AssemblyInformationalVersionAttribute>(
            typeof(QuotaDetailFormatter).Assembly)?.InformationalVersion.Split('+')[0]
        ?? typeof(QuotaDetailFormatter).Assembly.GetName().Version?.ToString(3)
        ?? "unknown";
    private static readonly string[] EnglishMonths =
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    public static QuotaDetailContent Format(
        AllowanceSnapshot snapshot,
        DateTimeOffset now,
        DisplayLanguage language,
        TimeZoneInfo timeZone,
        TokenUsageSnapshot? tokenUsage = null,
        AccountIdentity? account = null,
        string? version = null)
    {
        var copy = QuotaCopy.For(language);
        var rows = new List<QuotaDetailRow>();
        if (!string.IsNullOrEmpty(snapshot.PlanType))
        {
            rows.Add(new QuotaDetailRow(copy.Plan, Capitalize(snapshot.PlanType)));
        }
        rows.Add(new QuotaDetailRow(
            snapshot.Secondary is not null || snapshot.WindowDurationMinutes == 300
                ? language switch
                {
                    DisplayLanguage.SimplifiedChinese => "下次重置（5小时）",
                    DisplayLanguage.TraditionalChinese => "下次重設（5小時）",
                    _ => "Next reset (5 hours)",
                } : copy.NextReset,
            FormatDateWithInterval(snapshot.ResetsAt, now, language, timeZone), true, snapshot.RemainingPercent));
        if (snapshot.Secondary is { } secondary)
        {
            rows.Add(new QuotaDetailRow(
                copy.SecondaryNextReset,
                FormatDateWithInterval(secondary.ResetsAt, now, language, timeZone), true, secondary.RemainingPercent));
        }

        var primaryWindowLabel = snapshot.WindowDurationMinutes is { } primaryMinutes
            ? FormatPeriod(primaryMinutes, language)
            : copy.PrimaryQuotaWindow;
        var quotaWindows = new List<QuotaWindowPresentation>
        {
            new(primaryWindowLabel, snapshot.RemainingPercent),
        };
        if (snapshot.Secondary is { } secondaryWindow)
        {
            quotaWindows.Add(new QuotaWindowPresentation(
                copy.SecondaryQuotaWindowValue,
                secondaryWindow.RemainingPercent));
        }

        if (snapshot.Bank is { } bank)
        {
            rows.Add(new QuotaDetailRow(copy.BankAvailable, FormatBankCount(bank.AvailableCount, language)));
            var credits = (bank.Credits ?? [])
                .Select((credit, index) => (Credit: credit, Index: index))
                .OrderBy(item => item.Credit.ExpiresAt is null)
                .ThenBy(item => item.Credit.ExpiresAt)
                .ThenBy(item => item.Index)
                .Select(item => item.Credit)
                .ToArray();
            for (var index = 0; index < credits.Length; index++)
            {
                rows.Add(new QuotaDetailRow(
                    copy.BankExpiry(index + 1),
                    FormatBankExpiry(credits[index], now, language, timeZone, copy), true,
                    BankExpiryAccentPercent(credits[index].ExpiresAt, now)));
            }
            if (credits.Length == 0 && bank.AvailableCount > 0)
            {
                rows.Add(new QuotaDetailRow(copy.BankDetails, copy.NoData));
            }
        }
        else
        {
            rows.Add(new QuotaDetailRow(copy.BankAvailable, copy.NoData));
        }
        rows.Add(new QuotaDetailRow("Credits", FormatCredits(snapshot.Credits, copy)));
        rows.Add(new QuotaDetailRow(copy.Updated, FormatFreshness(snapshot.ReceivedAt, now, language, copy)));

        return new QuotaDetailContent(
            copy.Title,
            snapshot.RemainingPercent,
            rows,
            FormatTokenUsage(snapshot, tokenUsage, now, language, timeZone, copy),
            account,
            string.IsNullOrWhiteSpace(version) ? ProductVersion : version,
            copy.Account,
            quotaWindows);
    }

    private static int? BankExpiryAccentPercent(
        DateTimeOffset? expiresAt,
        DateTimeOffset now)
    {
        if (expiresAt is null) return null;
        var remaining = expiresAt.Value - now;
        if (remaining <= TimeSpan.FromDays(3)) return 10;
        if (remaining <= TimeSpan.FromDays(7)) return 49;
        return 100;
    }

    public static QuotaIndicatorSummary FormatIndicatorSummary(
        AllowanceSnapshot snapshot,
        DisplayLanguage language,
        TimeZoneInfo timeZone)
    {
        var copy = QuotaCopy.For(language);
        var primaryWindowLabel = snapshot.WindowDurationMinutes is { } primaryMinutes
            ? FormatPeriod(primaryMinutes, language)
            : copy.PrimaryQuotaWindow;
        var primary = FormatIndicatorLine(
            primaryWindowLabel,
            snapshot.RemainingPercent,
            snapshot.ResetsAt,
            language,
            timeZone);
        var secondary = snapshot.Secondary is { } window
            ? FormatIndicatorLine(
                copy.SecondaryQuotaWindowValue,
                window.RemainingPercent,
                window.ResetsAt,
                language,
                timeZone)
            : null;
        return new QuotaIndicatorSummary(
            primary,
            secondary,
            snapshot.RemainingPercent,
            snapshot.Secondary?.RemainingPercent);
    }

    public static IReadOnlyList<QuotaIndicatorRow> FormatIndicatorRows(
        AllowanceSnapshot snapshot, DisplayLanguage language, TimeZoneInfo timeZone)
    {
        string Date(DateTimeOffset reset)
        {
            var local = TimeZoneInfo.ConvertTime(reset, timeZone);
            return language == DisplayLanguage.English
                ? $"{EnglishMonths[local.Month - 1]} {local.Day}, {local:HH:mm}"
                : $"{local.Month}月{local.Day}日 {local:HH:mm}";
        }
        var copy = QuotaCopy.For(language);
        var rows = new List<QuotaIndicatorRow>
        {
            new(snapshot.WindowDurationMinutes is { } minutes ? FormatPeriod(minutes, language) : copy.PrimaryQuotaWindow,
                snapshot.RemainingPercent, Date(snapshot.ResetsAt)),
        };
        if (snapshot.Secondary is { } secondary)
            rows.Add(new(copy.SecondaryQuotaWindowValue, secondary.RemainingPercent, Date(secondary.ResetsAt)));
        return rows;
    }

    private static QuotaTokenUsageContent? FormatTokenUsage(
        AllowanceSnapshot snapshot,
        TokenUsageSnapshot? tokenUsage,
        DateTimeOffset now,
        DisplayLanguage language,
        TimeZoneInfo timeZone,
        QuotaCopy copy)
    {
        if (tokenUsage is null) return null;
        var cycle = TokenUsageWindow.Resolve(snapshot, tokenUsage, now, timeZone);
        var localNow = TimeZoneInfo.ConvertTime(now, timeZone);
        var days = Enumerable.Range(0, 7)
            .Select(offset => cycle.FirstDay.AddDays(offset))
            .Select(date =>
            {
                var tokens = cycle.TokensByDay.GetValueOrDefault(date);
                return new QuotaTokenUsageDay(
                    date,
                    FormatChartDate(date, language),
                    FormatTokenCount(tokens),
                    tokens,
                    date == DateOnly.FromDateTime(localNow.DateTime));
            })
            .ToArray();
        var total = cycle.Total;
        return new QuotaTokenUsageContent(
            copy.TokenTitle,
            cycle.Availability,
            days,
            total,
            cycle.Availability == TokenUsageAvailability.Available ? FormatTokenTotal(total, language) : copy.TokenUnavailable,
            copy.TokenUnavailable,
            cycle.Availability == TokenUsageAvailability.Available
                ? copy.TokenDelay
                : null);
    }

    private static string FormatChartDate(DateOnly date, DisplayLanguage language) => language switch
    {
        DisplayLanguage.English => $"{EnglishMonths[date.Month - 1]} {date.Day}",
        DisplayLanguage.TraditionalChinese => $"{date.Month}月{date.Day}日",
        _ => $"{date.Month}月{date.Day}日",
    };

    private static string FormatTokenTotal(long total, DisplayLanguage language)
    {
        var label = FormatTokenCount(total);
        return language switch
        {
            DisplayLanguage.English => $"This period total {label} tokens",
            DisplayLanguage.TraditionalChinese => $"本週期總計 {label} tokens",
            _ => $"本周期总计 {label} tokens",
        };
    }

    private static string FormatTokenCount(long tokens)
    {
        if (tokens >= 1_000_000_000) return $"{tokens / 1_000_000_000d:0.##}B";
        if (tokens >= 1_000_000) return $"{tokens / 1_000_000d:0.##}M";
        if (tokens >= 1_000) return $"{tokens / 1_000d:0.##}K";
        return tokens.ToString(System.Globalization.CultureInfo.InvariantCulture);
    }

    public static string FormatCompact(
        AllowanceSnapshot snapshot,
        DisplayLanguage language,
        TimeZoneInfo timeZone)
    {
        var local = TimeZoneInfo.ConvertTime(snapshot.ResetsAt, timeZone);
        var date = language == DisplayLanguage.English
            ? $"{EnglishMonths[local.Month - 1]} {local.Day}, {local:HH:mm}"
            : $"{local.Month}月{local.Day}日 {local:HH:mm}";
        return $"{snapshot.RemainingPercent}% · {date}";
    }

    private static string FormatIndicatorLine(
        string windowLabel,
        int remainingPercent,
        DateTimeOffset reset,
        DisplayLanguage language,
        TimeZoneInfo timeZone)
    {
        var local = TimeZoneInfo.ConvertTime(reset, timeZone);
        var date = language == DisplayLanguage.English
            ? $"{EnglishMonths[local.Month - 1]} {local.Day}, {local:HH:mm}"
            : $"{local.Month}月{local.Day}日 {local:HH:mm}";
        return $"{windowLabel} {remainingPercent}% · {date}";
    }

    private static string FormatDateWithInterval(
        DateTimeOffset date,
        DateTimeOffset now,
        DisplayLanguage language,
        TimeZoneInfo timeZone)
    {
        var local = TimeZoneInfo.ConvertTime(date, timeZone);
        var absolute = local.ToString("yyyy/MM/dd HH:mm", System.Globalization.CultureInfo.InvariantCulture);
        var relative = FormatRelative(now, date, language);
        return language == DisplayLanguage.English
            ? $"{relative}\n({absolute})"
            : $"{relative}\n（{absolute}）";
    }

    private static string FormatRelative(
        DateTimeOffset now,
        DateTimeOffset target,
        DisplayLanguage language)
    {
        var seconds = Math.Max(0, (target - now).TotalSeconds);
        if (seconds < 60) return "<1m";
        if (seconds < 3600) return language switch
        {
            DisplayLanguage.SimplifiedChinese => $"{(long)(seconds / 60)}分钟",
            DisplayLanguage.TraditionalChinese => $"{(long)(seconds / 60)}分鐘",
            _ => $"{(long)(seconds / 60)}m",
        };
        var hours = (long)(seconds / 3600);
        return language switch
        {
            DisplayLanguage.SimplifiedChinese => $"{hours / 24}天{hours % 24}小时",
            DisplayLanguage.TraditionalChinese => $"{hours / 24}天{hours % 24}小時",
            _ => $"{hours / 24}d {hours % 24}h",
        };
    }

    private static string FormatBankExpiry(
        BankResetCredit credit,
        DateTimeOffset now,
        DisplayLanguage language,
        TimeZoneInfo timeZone,
        QuotaCopy copy)
    {
        var status = credit.Status?.ToLowerInvariant();
        if (credit.ExpiresAt is not { } expiry)
        {
            return status switch
            {
                "used" => copy.NoExpiry + " · " + copy.Used,
                "expired" => copy.NoExpiry + " · " + copy.Expired,
                _ => copy.NoExpiry,
            };
        }
        var description = FormatDateWithInterval(expiry, now, language, timeZone);
        return status switch
        {
            "used" => description + " · " + copy.Used,
            "expired" => description + " · " + copy.Expired,
            _ when expiry <= now => description + " · " + copy.Expired,
            _ => description,
        };
    }

    private static string FormatCredits(CreditBalance? credits, QuotaCopy copy)
    {
        if (credits is null) return copy.NoData;
        if (credits.Unlimited) return copy.Unlimited;
        if (credits.HasCredits) return credits.Balance ?? copy.Available;
        return copy.None;
    }

    private static string FormatFreshness(
        DateTimeOffset receivedAt,
        DateTimeOffset now,
        DisplayLanguage language,
        QuotaCopy copy)
    {
        var seconds = Math.Max(0, (now - receivedAt).TotalSeconds);
        if (seconds < 60) return copy.JustNow;
        if (seconds < 3_600)
        {
            var minutes = (int)(seconds / 60);
            return language switch
            {
                DisplayLanguage.SimplifiedChinese => $"{minutes} 分钟前",
                DisplayLanguage.TraditionalChinese => $"{minutes} 分鐘前",
                _ => $"{minutes} {(minutes == 1 ? "minute" : "minutes")} ago",
            };
        }
        var hours = (int)(seconds / 3_600);
        return language switch
        {
            DisplayLanguage.SimplifiedChinese => $"{hours} 小时前",
            DisplayLanguage.TraditionalChinese => $"{hours} 小時前",
            _ => $"{hours} {(hours == 1 ? "hour" : "hours")} ago",
        };
    }

    private static string FormatPeriod(int minutes, DisplayLanguage language)
    {
        if (minutes % 1_440 == 0) return Duration(minutes / 1_440, language, "天", "天", "day");
        if (minutes % 60 == 0) return Duration(minutes / 60, language, "小时", "小時", "hour");
        return Duration(minutes, language, "分钟", "分鐘", "minute");
    }

    private static string Duration(
        int value,
        DisplayLanguage language,
        string simplified,
        string traditional,
        string english) => language switch
        {
            DisplayLanguage.SimplifiedChinese => $"{value} {simplified}",
            DisplayLanguage.TraditionalChinese => $"{value} {traditional}",
            _ => $"{value} {english}{(value == 1 ? string.Empty : "s")}",
        };

    private static string FormatBankCount(int count, DisplayLanguage language) =>
        language == DisplayLanguage.English
            ? $"{count} {(count == 1 ? "reset" : "resets")}"
            : $"{count} 次";

    private static string Capitalize(string value) => value.Length == 0
        ? value
        : char.ToUpperInvariant(value[0]) + value[1..];

    private sealed record QuotaCopy(
        string Title,
        string Plan,
        string QuotaWindow,
        string PrimaryQuotaWindow,
        string SecondaryQuotaWindow,
        string SecondaryQuotaWindowValue,
        string NextReset,
        string SecondaryNextReset,
        string BankAvailable,
        Func<int, string> BankExpiry,
        string BankDetails,
        string Updated,
        string NoData,
        string Unlimited,
        string Available,
        string None,
        string NoExpiry,
        string Used,
        string Expired,
        string JustNow,
        string Account,
        string TokenTitle,
        string TokenUnavailable,
        string TokenDelay)
    {
        public static QuotaCopy For(DisplayLanguage language) => language switch
        {
            DisplayLanguage.SimplifiedChinese => new(
                "Codex 剩余额度", "套餐", "额度周期", "5 小时", "额度周期（7天）", "7 天", "下次重置", "下次重置（7天）", "Bank 可用重置",
                index => $"Bank {index}到期时间", "Bank 明细", "数据更新", "暂无数据",
                "无限", "可用", "无", "未提供到期时间", "已使用", "已过期", "刚刚",
                "账户", "Token 用量",
                "Token 使用量暂不可用", "数据可能延迟"),
            DisplayLanguage.TraditionalChinese => new(
                "Codex 剩餘額度", "方案", "額度週期", "5 小時", "額度週期（7天）", "7 天", "下次重設", "下次重設（7天）", "Bank 可用重設",
                index => $"Bank {index}到期時間", "Bank 詳情", "資料更新", "暫無資料",
                "無限", "可用", "無", "未提供到期時間", "已使用", "已過期", "剛剛",
                "帳戶", "Token 用量",
                "Token 使用量暫不可用", "資料可能延遲"),
            _ => new(
                "Codex quota", "Plan", "Quota window", "5 hours", "Quota window (7 days)", "7 days", "Next reset", "Next reset (7 days)", "Bank resets available",
                index => $"Bank {index} expires", "Bank details", "Updated", "No data",
                "Unlimited", "Available", "None", "No expiry provided", "Used", "Expired", "Just now",
                "Account", "Token usage",
                "Token usage unavailable", "Usage data may be delayed"),
        };
    }
}
