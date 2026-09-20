#if WINDOWS
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class QuotaDetailVisualFixtureTests
{
    [STATestMethod]
    public void LightPaletteUsesAnOpaquePureWhiteDetailSurface()
    {
        var surface = (SolidColorBrush)WpfOverlayPalette.Light.Surface;
        Assert.AreEqual(Color.FromArgb(255, 255, 255, 255), surface.Color);
        Assert.AreEqual(1d, surface.Opacity);
    }

    [STATestMethod]
    public void RendersTheProductionCardInEverySupportedLanguageAndTheme()
    {
        Application.ResourceAssembly ??= typeof(WpfOverlaySurface).Assembly;
        var outputDirectory = Environment.GetEnvironmentVariable("CUS_WINDOWS_VISUAL_OUTPUT_DIR");
        if (!string.IsNullOrWhiteSpace(outputDirectory)) Directory.CreateDirectory(outputDirectory);

        foreach (var (language, languageName) in Languages)
        foreach (var (palette, themeName) in Themes)
        {
            var surface = new WpfOverlaySurface(language, TimeZoneInfo.Utc);
            var content = QuotaDetailFormatter.Format(
                Snapshot,
                Now,
                language,
                TimeZoneInfo.Utc,
                TokenUsage,
                new AccountIdentity("Jace", "jace@example.com", null),
                "0.4.0");
            var card = surface.BuildDetailCardForVisualFixture(content, palette);
            Layout(card);

            Assert.AreEqual(2, Descendants<WpfQuotaProgressBar>(card).Count());
            Assert.AreEqual(1, Descendants<ToggleButton>(card).Count());
            Assert.AreEqual(2, Descendants<Button>(card).Count());
            Assert.AreEqual(QuotaDetailViewportPolicy.DefaultRowViewportHeight,
                Descendants<ScrollViewer>(card).Single().Height);
            var texts = Descendants<TextBlock>(card).Select(item => item.Text).ToArray();
            CollectionAssert.Contains(texts, content.Title);
            CollectionAssert.Contains(texts, "Jace");
            CollectionAssert.Contains(texts, "v0.4.0");
            Assert.IsFalse(texts.Any(text => text.Contains("Tibo", StringComparison.OrdinalIgnoreCase)));

            if (!string.IsNullOrWhiteSpace(outputDirectory))
                Render(card, Path.Combine(outputDirectory, $"quota-{languageName}-{themeName}.png"));
        }
    }

    [STATestMethod]
    public void FooterRendersEmailWhenDisplayNameIsUnavailable()
    {
        Application.ResourceAssembly ??= typeof(WpfOverlaySurface).Assembly;
        var surface = new WpfOverlaySurface(DisplayLanguage.English, TimeZoneInfo.Utc);
        var content = QuotaDetailFormatter.Format(
            Snapshot, Now, DisplayLanguage.English, TimeZoneInfo.Utc, TokenUsage,
            new AccountIdentity(null, "demo@example.com", null), "0.4.0");
        var card = surface.BuildDetailCardForVisualFixture(content, WpfOverlayPalette.Light);
        Layout(card);
        var texts = Descendants<TextBlock>(card).Select(item => item.Text).ToArray();
        CollectionAssert.Contains(texts, "demo@example.com");
    }

    private static void Layout(FrameworkElement element)
    {
        element.Measure(new Size(OverlayVisualMetrics.DetailWidth, double.PositiveInfinity));
        element.Arrange(new Rect(0, 0, OverlayVisualMetrics.DetailWidth, element.DesiredSize.Height));
        element.UpdateLayout();
    }

    private static void Render(FrameworkElement element, string path)
    {
        const double scale = 2;
        var bitmap = new RenderTargetBitmap(
            (int)Math.Ceiling(element.ActualWidth * scale),
            (int)Math.Ceiling(element.ActualHeight * scale),
            96 * scale,
            96 * scale,
            PixelFormats.Pbgra32);
        bitmap.Render(element);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var output = File.Create(path);
        encoder.Save(output);
        Assert.IsTrue(output.Length > 1_000, $"Visual fixture is unexpectedly empty: {path}");
    }

    private static IEnumerable<T> Descendants<T>(DependencyObject root) where T : DependencyObject
    {
        for (var index = 0; index < VisualTreeHelper.GetChildrenCount(root); index++)
        {
            var child = VisualTreeHelper.GetChild(root, index);
            if (child is T match) yield return match;
            foreach (var descendant in Descendants<T>(child)) yield return descendant;
        }
    }

    private static readonly DateTimeOffset Now = new(2026, 9, 9, 8, 0, 0, TimeSpan.Zero);
    private static AllowanceSnapshot Snapshot => new(
        15,
        85,
        Now.AddHours(3),
        Now,
        300,
        "plus",
        new CreditBalance(false, false, null),
        new BankResetSummary(12, Enumerable.Range(1, 12)
            .Select(index => new BankResetCredit(
                "available", null, Now.AddDays(index), null, null))
            .ToArray()),
        new QuotaWindowSnapshot(2, 98, Now.AddDays(4).AddHours(23), 10_080));
    private static TokenUsageSnapshot TokenUsage => new(
        Now,
        Enumerable.Range(0, 7)
            .Select(index => new TokenUsageDay(DateOnly.FromDateTime(Now.UtcDateTime).AddDays(-6 + index),
                (index + 1) * 100_000L))
            .ToArray(),
        null,
        TokenUsageAvailability.Available);

    private static readonly (DisplayLanguage Language, string Name)[] Languages =
    [
        (DisplayLanguage.SimplifiedChinese, "zh-cn"),
        (DisplayLanguage.TraditionalChinese, "zh-tw"),
        (DisplayLanguage.English, "en"),
    ];
    private static readonly (WpfOverlayPalette Palette, string Name)[] Themes =
    [
        (WpfOverlayPalette.Light, "light"),
        (WpfOverlayPalette.Dark, "dark"),
    ];
}
#endif
