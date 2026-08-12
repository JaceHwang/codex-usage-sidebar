namespace CodexUsageSidebar.Core;

public enum QuotaCountdownSegmentRole
{
    Plain,
    Punctuation,
    Digits,
    Unit,
    Suffix,
}

public readonly record struct QuotaCountdownSegment(
    string Text,
    QuotaCountdownSegmentRole Role);

public static class QuotaCountdownSegmenter
{
    public static IReadOnlyList<QuotaCountdownSegment> Segments(string value)
    {
        ArgumentNullException.ThrowIfNull(value);
        var candidates = new List<Candidate>();
        AddCandidate(value, '（', '）', candidates);
        AddCandidate(value, '(', ')', candidates);
        if (candidates.Count == 0)
        {
            return [new QuotaCountdownSegment(value, QuotaCountdownSegmentRole.Plain)];
        }

        var candidate = candidates.MaxBy(item => item.OpeningIndex)!;
        var result = new List<QuotaCountdownSegment>();
        Append(value[..candidate.OpeningIndex], QuotaCountdownSegmentRole.Plain, result);
        Append(value[candidate.OpeningIndex].ToString(), QuotaCountdownSegmentRole.Punctuation, result);
        foreach (var segment in candidate.IntervalSegments)
        {
            Append(segment.Text, segment.Role, result);
        }
        Append(value[candidate.ClosingIndex].ToString(), QuotaCountdownSegmentRole.Punctuation, result);
        Append(value[(candidate.ClosingIndex + 1)..], QuotaCountdownSegmentRole.Plain, result);
        return result;
    }

    private static void AddCandidate(
        string value,
        char opening,
        char closing,
        List<Candidate> candidates)
    {
        var openingIndex = value.LastIndexOf(opening);
        if (openingIndex < 0) return;
        var closingIndex = value.IndexOf(closing, openingIndex + 1);
        if (closingIndex < 0) return;
        var interval = value[(openingIndex + 1)..closingIndex];
        var intervalSegments = ParseInterval(interval);
        if (intervalSegments is null) return;
        candidates.Add(new Candidate(openingIndex, closingIndex, intervalSegments));
    }

    private static IReadOnlyList<QuotaCountdownSegment>? ParseInterval(string interval)
    {
        var cursor = 0;
        var segments = new List<QuotaCountdownSegment>();
        if (cursor < interval.Length && interval[cursor] == '<')
        {
            Append("<", QuotaCountdownSegmentRole.Punctuation, segments);
            cursor++;
        }

        var pairCount = 0;
        while (cursor < interval.Length)
        {
            var digitsStart = cursor;
            while (cursor < interval.Length && char.IsDigit(interval[cursor])) cursor++;
            if (digitsStart == cursor || cursor >= interval.Length) break;
            var unit = interval[cursor];
            if (unit is not ('d' or 'h' or 'm')) break;
            Append(interval[digitsStart..cursor], QuotaCountdownSegmentRole.Digits, segments);
            Append(unit.ToString(), QuotaCountdownSegmentRole.Unit, segments);
            cursor++;
            pairCount++;
        }

        if (pairCount == 0) return null;
        var suffix = interval[cursor..];
        if (suffix is not ("" or "前" or " ago")) return null;
        Append(suffix, QuotaCountdownSegmentRole.Suffix, segments);
        return segments;
    }

    private static void Append(
        string text,
        QuotaCountdownSegmentRole role,
        List<QuotaCountdownSegment> segments)
    {
        if (text.Length == 0) return;
        if (segments.Count > 0 && segments[^1].Role == role)
        {
            segments[^1] = segments[^1] with { Text = segments[^1].Text + text };
            return;
        }
        segments.Add(new QuotaCountdownSegment(text, role));
    }

    private sealed record Candidate(
        int OpeningIndex,
        int ClosingIndex,
        IReadOnlyList<QuotaCountdownSegment> IntervalSegments);
}
