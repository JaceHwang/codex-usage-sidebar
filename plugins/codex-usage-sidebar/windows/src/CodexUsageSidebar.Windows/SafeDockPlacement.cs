using System.Text.Json;
using System.Text.Json.Serialization;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public enum SafeDockSize
{
    Standard,
    Compact,
}

public enum SafeDockAnchor
{
    Top,
    Left,
    Right,
}

public enum SafeDockNoPlacementReason
{
    None,
    InvalidGeometry,
    HostTooSmall,
}

public sealed record SafeDockPreferences(
    bool FallbackLocked,
    SafeDockSize Size,
    SafeDockAnchor Anchor,
    PointD Offset)
{
    public static SafeDockPreferences Default { get; } = new(
        FallbackLocked: false,
        Size: SafeDockSize.Standard,
        Anchor: SafeDockAnchor.Right,
        Offset: new PointD(0, 0));
}

public readonly record struct SafeDockPlacementRequest(
    RectD HostBounds,
    RectD WorkArea,
    RectD CaptionBounds,
    double DpiScale,
    SafeDockPreferences Preferences);

public readonly record struct SafeDockPlacementResult(
    RectD? Frame,
    SafeDockSize Size,
    SafeDockNoPlacementReason NoPlacementReason);

public static class SafeDockPlacementResolver
{
    private const double InsetDip = 8;
    private const double MinimumCaptionClearanceDip = 72;

    public static SafeDockPlacementResult Resolve(SafeDockPlacementRequest request)
    {
        if (!IsUsable(request.HostBounds)
            || !IsUsable(request.WorkArea)
            || !double.IsFinite(request.DpiScale)
            || request.DpiScale <= 0
            || request.Preferences is null)
        {
            return NoPlacement(SafeDockNoPlacementReason.InvalidGeometry, request.Preferences?.Size ?? SafeDockSize.Standard);
        }

        var bounds = Intersection(request.HostBounds, request.WorkArea);
        if (!IsUsable(bounds))
        {
            return NoPlacement(SafeDockNoPlacementReason.HostTooSmall, request.Preferences.Size);
        }

        foreach (var size in CandidateSizes(request.Preferences.Size))
        {
            var indicator = SizeFor(size, request.DpiScale);
            var frame = ResolveFrame(bounds, request.HostBounds, request.CaptionBounds, indicator, request);
            if (frame is not null)
            {
                return new SafeDockPlacementResult(frame, size, SafeDockNoPlacementReason.None);
            }
        }

        return NoPlacement(SafeDockNoPlacementReason.HostTooSmall, request.Preferences.Size);
    }

    public static CompatibilitySize SizeFor(SafeDockSize size, double dpiScale)
    {
        var width = size == SafeDockSize.Compact
            ? OverlayVisualMetrics.CompactIndicatorWidth
            : OverlayVisualMetrics.IndicatorWidth;
        return new CompatibilitySize(width * dpiScale, OverlayVisualMetrics.IndicatorHeight * dpiScale);
    }

    private static IEnumerable<SafeDockSize> CandidateSizes(SafeDockSize preferred)
    {
        yield return preferred;
        if (preferred == SafeDockSize.Standard) yield return SafeDockSize.Compact;
    }

    private static RectD? ResolveFrame(
        RectD bounds,
        RectD host,
        RectD caption,
        CompatibilitySize indicator,
        SafeDockPlacementRequest request)
    {
        var inset = InsetDip * request.DpiScale;
        var captionBottom = IsUsable(caption) ? caption.Bottom + inset : double.NegativeInfinity;
        var minimumTop = Math.Max(captionBottom, host.Y + (MinimumCaptionClearanceDip * request.DpiScale));
        var minimumX = bounds.X + inset;
        var maximumX = bounds.Right - inset - indicator.Width;
        var minimumY = Math.Max(bounds.Y + inset, minimumTop);
        var maximumY = bounds.Bottom - inset - indicator.Height;
        if (maximumX < minimumX || maximumY < minimumY)
        {
            return null;
        }

        var offsetX = request.Preferences.Offset.X * request.DpiScale;
        var offsetY = request.Preferences.Offset.Y * request.DpiScale;
        var x = request.Preferences.Anchor switch
        {
            SafeDockAnchor.Top => minimumX + offsetX,
            SafeDockAnchor.Left => minimumX,
            _ => maximumX,
        };
        var y = request.Preferences.Anchor switch
        {
            SafeDockAnchor.Top => minimumY,
            SafeDockAnchor.Left => minimumY + offsetY,
            _ => minimumY + offsetY,
        };
        return new RectD(
            Math.Clamp(x, minimumX, maximumX),
            Math.Clamp(y, minimumY, maximumY),
            indicator.Width,
            indicator.Height);
    }

    private static SafeDockPlacementResult NoPlacement(SafeDockNoPlacementReason reason, SafeDockSize size) =>
        new(null, size, reason);

    private static RectD Intersection(RectD left, RectD right)
    {
        var x = Math.Max(left.X, right.X);
        var y = Math.Max(left.Y, right.Y);
        return new RectD(x, y, Math.Min(left.Right, right.Right) - x, Math.Min(left.Bottom, right.Bottom) - y);
    }

    private static bool IsUsable(RectD bounds) =>
        double.IsFinite(bounds.X)
        && double.IsFinite(bounds.Y)
        && double.IsFinite(bounds.Width)
        && double.IsFinite(bounds.Height)
        && bounds.Width > 0
        && bounds.Height > 0;
}

public static class SafeDockIndicatorText
{
    public static string Format(int remainingPercent, SafeDockSize size) =>
        size == SafeDockSize.Compact ? $"{remainingPercent}%" : string.Empty;
}

public static class SafeDockDragSnapPolicy
{
    public static SafeDockPreferences Snap(SafeDockPlacementRequest request, RectD releasedFrame)
    {
        var scale = request.DpiScale;
        if (!double.IsFinite(scale) || scale <= 0 || request.Preferences is null)
        {
            return request.Preferences ?? SafeDockPreferences.Default;
        }

        var inset = 8 * scale;
        var captionBottom = IsUsable(request.CaptionBounds)
            ? request.CaptionBounds.Bottom + inset
            : double.NegativeInfinity;
        var top = Math.Max(
            Math.Max(request.WorkArea.Y + inset, request.HostBounds.Y + (72 * scale)),
            captionBottom);
        var left = Math.Max(request.WorkArea.X, request.HostBounds.X) + inset;
        var right = Math.Min(request.WorkArea.Right, request.HostBounds.Right) - inset;
        var topDistance = Math.Abs(releasedFrame.Y - top);
        var leftDistance = Math.Abs(releasedFrame.X - left);
        var rightDistance = Math.Abs(releasedFrame.Right - right);
        if (topDistance <= leftDistance && topDistance <= rightDistance)
        {
            return request.Preferences with
            {
                Anchor = SafeDockAnchor.Top,
                Offset = new PointD((releasedFrame.X - left) / scale, 0),
            };
        }
        if (leftDistance <= rightDistance)
        {
            return request.Preferences with
            {
                Anchor = SafeDockAnchor.Left,
                Offset = new PointD(0, (releasedFrame.Y - top) / scale),
            };
        }
        return request.Preferences with
        {
            Anchor = SafeDockAnchor.Right,
            Offset = new PointD(0, (releasedFrame.Y - top) / scale),
        };
    }

    private static bool IsUsable(RectD bounds) =>
        double.IsFinite(bounds.X)
        && double.IsFinite(bounds.Y)
        && double.IsFinite(bounds.Width)
        && double.IsFinite(bounds.Height)
        && bounds.Width > 0
        && bounds.Height > 0;
}

public interface ISafeDockPreferencesStore
{
    ValueTask<SafeDockPreferences> LoadAsync(CancellationToken cancellationToken);
    ValueTask SaveAsync(SafeDockPreferences preferences, CancellationToken cancellationToken);
}

public sealed class SafeDockPreferencesStore(string path) : ISafeDockPreferencesStore
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        Converters = { new JsonStringEnumConverter() },
    };

    public async ValueTask<SafeDockPreferences> LoadAsync(CancellationToken cancellationToken)
    {
        if (!File.Exists(path)) return SafeDockPreferences.Default;
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        return await JsonSerializer.DeserializeAsync<SafeDockPreferences>(stream, SerializerOptions, cancellationToken)
            .ConfigureAwait(false)
            ?? SafeDockPreferences.Default;
    }

    public async ValueTask SaveAsync(SafeDockPreferences preferences, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(preferences);
        var directory = Path.GetDirectoryName(path);
        if (string.IsNullOrWhiteSpace(directory))
        {
            throw new ArgumentException("The safe-dock preferences path must include a directory.", nameof(path));
        }

        Directory.CreateDirectory(directory);
        var temporaryPath = Path.Combine(directory, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            await using (var stream = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                bufferSize: 4096,
                FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                await JsonSerializer.SerializeAsync(stream, preferences, SerializerOptions, cancellationToken).ConfigureAwait(false);
                await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
            }
            File.Move(temporaryPath, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
        }
    }
}
