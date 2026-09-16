using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class IndicatorPreferencesStoreTests
{
    [TestMethod]
    public async Task SavedModeAndMultipleDisplayPositionsSurviveRestart()
    {
        var directory = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        try
        {
            var store = new IndicatorPreferencesStore(Path.Combine(directory, "placement.json"));
            var preferences = new IndicatorPlacementPreferences { Mode = IndicatorPlacementMode.Free };
            preferences.Capture("left", new(-1500, 300, 200, 40), new(-1920, 40, 1920, 1040));
            preferences.Capture("right", new(900, 500, 200, 40), new(0, 0, 1920, 1080));
            await store.SaveAsync(preferences, CancellationToken.None);
            var restored = await new IndicatorPreferencesStore(Path.Combine(directory, "placement.json")).LoadAsync(CancellationToken.None);
            Assert.AreEqual(IndicatorPlacementMode.Free, restored.Mode);
            Assert.AreEqual("right", restored.ActiveDisplayId);
            Assert.AreEqual(new RectD(-1500, 300, 200, 40), restored.Resolve("left", new(-1920, 40, 1920, 1040), new(0, 0, 200, 40)));
            Assert.AreEqual(1, Directory.GetFiles(directory).Length);
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }

    [DataTestMethod]
    [DataRow("{broken")]
    [DataRow("{\"Mode\":\"UnknownFutureMode\"}")]
    [DataRow("{\"Mode\":99,\"Placements\":null}")]
    public async Task InvalidPreferencesRecoverToAutomaticWithoutRewritingTheFile(string contents)
    {
        var path = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N") + ".json");
        try
        {
            await File.WriteAllTextAsync(path, contents);
            var preferences = await new IndicatorPreferencesStore(path).LoadAsync(CancellationToken.None);
            Assert.AreEqual(IndicatorPlacementMode.Automatic, preferences.Mode);
            Assert.AreEqual(0, preferences.Placements.Count);
            Assert.AreEqual(contents, await File.ReadAllTextAsync(path));
        }
        finally { File.Delete(path); }
    }
}
