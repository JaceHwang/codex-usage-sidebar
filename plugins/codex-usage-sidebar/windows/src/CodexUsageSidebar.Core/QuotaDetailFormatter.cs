namespace CodexUsageSidebar.Core;

public sealed record QuotaDetailRow(string Label, string Value);

public sealed record QuotaDetailContent(
    string Title,
    int RemainingPercent,
    IReadOnlyList<QuotaDetailRow> Rows);

public static class QuotaDetailFormatter
{
    private static readonly string[] EnglishMonths =
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    public static QuotaDetailContent Format(
        AllowanceSnapshot snapshot,
        DateTimeOffset now,
        DisplayLanguage language,
        TimeZoneInfo timeZone)
    {
        var copy = QuotaCopy.For(language);
        var rows = new List<QuotaDetailRow>();
        if (!string.IsNullOrEmpty(snapshot.PlanType))
        {
            rows.Add(new QuotaDetailRow(copy.Plan, Capitalize(snapshot.PlanType)));
        }
        if (snapshot.WindowDurationMinutes is > 0)
        {
            rows.Add(new QuotaDetailRow(
                copy.QuotaWindow,
                FormatPeriod(snapshot.WindowDurationMinutes.Value, language)));
        }
        rows.Add(new QuotaDetailRow(
            copy.NextReset,
            FormatDateWithInterval(snapshot.ResetsAt, now, language, timeZone)));
        rows.Add(new QuotaDetailRow("Credits", FormatCredits(snapshot.Credits, copy)));

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
                    FormatBankExpiry(credits[index], now, language, timeZone, copy)));
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
        rows.Add(new QuotaDetailRow(copy.Updated, FormatFreshness(snapshot.ReceivedAt, now, language, copy)));

        return new QuotaDetailContent(copy.Title, snapshot.RemainingPercent, rows);
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

    private static string FormatDateWithInterval(
        DateTimeOffset date,
        DateTimeOffset now,
        DisplayLanguage language,
        TimeZoneInfo timeZone)
    {
        var local = TimeZoneInfo.ConvertTime(date, timeZone);
        var absolute = language == DisplayLanguage.English
            ? $"{EnglishMonths[local.Month - 1]} {local.Day}, {local:HH:mm}"
            : $"{local.Month}月{local.Day}日 {local:HH:mm}";
        var relative = FormatRelative(now, date, language);
        return language == DisplayLanguage.English
            ? $"{absolute} ({relative})"
            : $"{absolute}（{relative}）";
    }

    private static string FormatRelative(
        DateTimeOffset now,
        DateTimeOffset target,
        DisplayLanguage language)
    {
        var interval = target - now;
        var totalSeconds = (long)Math.Floor(Math.Abs(interval.TotalSeconds));
        string value;
        if (totalSeconds >= 86_400)
        {
            value = $"{totalSeconds / 86_400}d{totalSeconds % 86_400 / 3_600}h";
        }
        else if (totalSeconds >= 3_600)
        {
            value = $"{totalSeconds / 3_600}h{totalSeconds % 3_600 / 60}m";
        }
        else if (totalSeconds >= 60)
        {
            value = $"{totalSeconds / 60}m";
        }
        else
        {
            value = "<1m";
        }
        if (interval >= TimeSpan.Zero)
        {
            return value;
        }
        return language == DisplayLanguage.English ? value + " ago" : value + "前";
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
        string NextReset,
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
        string JustNow)
    {
        public static QuotaCopy For(DisplayLanguage language) => language switch
        {
            DisplayLanguage.SimplifiedChinese => new(
                "Codex 剩余额度", "套餐", "额度周期", "下次重置", "Bank 可用重置",
                index => $"Bank {index}到期时间", "Bank 明细", "数据更新", "暂无数据",
                "无限", "可用", "无", "未提供到期时间", "已使用", "已过期", "刚刚"),
            DisplayLanguage.TraditionalChinese => new(
                "Codex 剩餘額度", "方案", "額度週期", "下次重設", "Bank 可用重設",
                index => $"Bank {index}到期時間", "Bank 詳情", "資料更新", "暫無資料",
                "無限", "可用", "無", "未提供到期時間", "已使用", "已過期", "剛剛"),
            _ => new(
                "Codex quota", "Plan", "Quota window", "Next reset", "Bank resets available",
                index => $"Bank {index} expires", "Bank details", "Updated", "No data",
                "Unlimited", "Available", "None", "No expiry provided", "Used", "Expired", "Just now"),
        };
    }
}
