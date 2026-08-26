using System.Text.Json;

namespace CodexUsageSidebar.Core;

public static class RateLimitDecoder
{
    public static AllowanceSnapshot DecodeResponse(string json, DateTimeOffset receivedAt)
    {
        using var document = Parse(json);
        var root = document.RootElement;
        return DecodeContainer(TryProperty(root, "result", out var result) ? result : root, receivedAt);
    }

    public static AllowanceSnapshot DecodeNotification(string json, DateTimeOffset receivedAt)
    {
        using var document = Parse(json);
        var root = document.RootElement;
        if (!TryProperty(root, "method", out var method)
            || method.ValueKind != JsonValueKind.String
            || method.GetString() != "account/rateLimits/updated"
            || !TryProperty(root, "params", out var parameters))
        {
            throw new RateLimitDecodingException(RateLimitDecodingFailure.MissingCodexBucket);
        }

        return DecodeContainer(parameters, receivedAt);
    }

    private static JsonDocument Parse(string json)
    {
        try
        {
            var document = JsonDocument.Parse(json);
            if (document.RootElement.ValueKind == JsonValueKind.Object)
            {
                return document;
            }
            document.Dispose();
        }
        catch (JsonException)
        {
        }

        throw new RateLimitDecodingException(RateLimitDecodingFailure.InvalidJson);
    }

    private static AllowanceSnapshot DecodeContainer(JsonElement container, DateTimeOffset receivedAt)
    {
        JsonElement bucket;
        if (TryProperty(container, "rateLimitsByLimitId", out var buckets)
            && TryProperty(buckets, "codex", out var codex))
        {
            bucket = codex;
        }
        else if (TryProperty(container, "rateLimits", out var direct)
                 && (!TryProperty(direct, "limitId", out var limitId)
                     || (limitId.ValueKind == JsonValueKind.String && limitId.GetString() == "codex")))
        {
            bucket = direct;
        }
        else if (TryProperty(container, "primary", out _))
        {
            bucket = container;
        }
        else
        {
            throw new RateLimitDecodingException(RateLimitDecodingFailure.MissingCodexBucket);
        }

        if (!TryProperty(bucket, "primary", out var primary))
        {
            throw new RateLimitDecodingException(RateLimitDecodingFailure.MissingCodexBucket);
        }

        var usedPercent = RequiredFiniteNumber(primary, "usedPercent", RateLimitDecodingFailure.MissingUsedPercent);
        var resetTimestamp = RequiredFiniteNumber(primary, "resetsAt", RateLimitDecodingFailure.MissingResetTime);
        if (resetTimestamp <= 0)
        {
            throw new RateLimitDecodingException(RateLimitDecodingFailure.InvalidNumber);
        }

        var remaining = (int)Math.Round(Math.Clamp(100d - usedPercent, 0, 100), MidpointRounding.AwayFromZero);
        return new AllowanceSnapshot(
            usedPercent,
            remaining,
            DateTimeOffset.FromUnixTimeSeconds(checked((long)resetTimestamp)),
            receivedAt,
            OptionalInteger(primary, "windowDurationMins"),
            OptionalString(bucket, "planType"),
            DecodeCredits(bucket),
            DecodeBank(container),
            DecodeWindow(bucket));
    }

    private static QuotaWindowSnapshot? DecodeWindow(JsonElement bucket)
    {
        if (!TryProperty(bucket, "secondary", out var window)
            || window.ValueKind != JsonValueKind.Object
            || !TryProperty(window, "usedPercent", out var usedProperty)
            || usedProperty.ValueKind != JsonValueKind.Number
            || !usedProperty.TryGetDouble(out var usedPercent)
            || !double.IsFinite(usedPercent)
            || !TryProperty(window, "resetsAt", out var resetProperty)
            || resetProperty.ValueKind != JsonValueKind.Number
            || !resetProperty.TryGetDouble(out var resetTimestamp)
            || !double.IsFinite(resetTimestamp)
            || resetTimestamp <= 0)
        {
            return null;
        }

        var remaining = (int)Math.Round(
            Math.Clamp(100d - usedPercent, 0, 100),
            MidpointRounding.AwayFromZero);
        return new QuotaWindowSnapshot(
            usedPercent,
            remaining,
            DateTimeOffset.FromUnixTimeSeconds(checked((long)resetTimestamp)),
            OptionalInteger(window, "windowDurationMins"));
    }

    private static CreditBalance? DecodeCredits(JsonElement bucket)
    {
        if (!TryProperty(bucket, "credits", out var credits) || credits.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        return new CreditBalance(
            OptionalBoolean(credits, "hasCredits") ?? false,
            OptionalBoolean(credits, "unlimited") ?? false,
            OptionalString(credits, "balance"));
    }

    private static BankResetSummary? DecodeBank(JsonElement container)
    {
        if (!TryProperty(container, "rateLimitResetCredits", out var bank)
            || bank.ValueKind != JsonValueKind.Object
            || OptionalInteger(bank, "availableCount") is not { } availableCount)
        {
            return null;
        }

        IReadOnlyList<BankResetCredit>? details = null;
        if (TryProperty(bank, "credits", out var credits) && credits.ValueKind == JsonValueKind.Array)
        {
            details = credits.EnumerateArray()
                .Where(x => x.ValueKind == JsonValueKind.Object)
                .Select(x => new BankResetCredit(
                    OptionalString(x, "status"),
                    OptionalDate(x, "grantedAt"),
                    OptionalDate(x, "expiresAt"),
                    OptionalString(x, "title"),
                    OptionalString(x, "description")))
                .ToArray();
        }

        return new BankResetSummary(Math.Max(0, availableCount), details);
    }

    private static double RequiredFiniteNumber(JsonElement value, string name, RateLimitDecodingFailure missing)
    {
        if (!TryProperty(value, name, out var property))
        {
            throw new RateLimitDecodingException(missing);
        }
        if (property.ValueKind != JsonValueKind.Number || !property.TryGetDouble(out var number) || !double.IsFinite(number))
        {
            throw new RateLimitDecodingException(RateLimitDecodingFailure.InvalidNumber);
        }
        return number;
    }

    private static bool TryProperty(JsonElement value, string name, out JsonElement property)
    {
        property = default;
        return value.ValueKind == JsonValueKind.Object && value.TryGetProperty(name, out property);
    }

    private static int? OptionalInteger(JsonElement value, string name) =>
        TryProperty(value, name, out var property) && property.ValueKind == JsonValueKind.Number && property.TryGetInt32(out var result)
            ? result : null;

    private static bool? OptionalBoolean(JsonElement value, string name) =>
        TryProperty(value, name, out var property) && property.ValueKind is JsonValueKind.True or JsonValueKind.False
            ? property.GetBoolean() : null;

    private static string? OptionalString(JsonElement value, string name) =>
        TryProperty(value, name, out var property) && property.ValueKind == JsonValueKind.String
            ? property.GetString() : null;

    private static DateTimeOffset? OptionalDate(JsonElement value, string name)
    {
        if (!TryProperty(value, name, out var property)
            || property.ValueKind != JsonValueKind.Number
            || !property.TryGetInt64(out var timestamp)
            || timestamp <= 0)
        {
            return null;
        }
        return DateTimeOffset.FromUnixTimeSeconds(timestamp);
    }
}
