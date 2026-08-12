namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class DiagnosticSanitizerTests
{
    [TestMethod]
    public void DefaultProbeBudgetReachesTheChromiumContentToolbar()
    {
        Assert.IsTrue(UiaTraversalBudget.DiagnosticMaximumDepth >= 24);
        Assert.IsTrue(UiaTraversalBudget.DiagnosticMaximumNodes >= 2_000);
    }

    [TestMethod]
    public void RejectsNonFiniteUiaBoundsBeforeDiagnosticSerialization()
    {
        Assert.IsFalse(UiaTraversalBudget.HasFiniteBounds(new(
            double.PositiveInfinity,
            0,
            100,
            40)));
        Assert.IsFalse(UiaTraversalBudget.HasFiniteBounds(new(
            0,
            double.NaN,
            100,
            40)));
        Assert.IsTrue(UiaTraversalBudget.HasFiniteBounds(new(-13, -13, 3026, 1930)));
    }

    [TestMethod]
    public void ClassifiesKnownOpenLocationLabelsWithoutPersistingTheirText()
    {
        CollectionAssert.AreEquivalent(
            new[] { "打开位置", "開啟位置", "Open Location" },
            UiaSemanticRoleClassifier.SupportedExactNames.ToArray());
        Assert.AreEqual(UiaSemanticRoles.OpenLocation, UiaSemanticRoleClassifier.Classify("打开位置"));
        Assert.AreEqual(UiaSemanticRoles.OpenLocation, UiaSemanticRoleClassifier.Classify("開啟位置"));
        Assert.AreEqual(UiaSemanticRoles.OpenLocation, UiaSemanticRoleClassifier.Classify("Open Location"));
        Assert.AreEqual(UiaSemanticRoles.None, UiaSemanticRoleClassifier.Classify("次要操作"));
        Assert.AreEqual(UiaSemanticRoles.None, UiaSemanticRoleClassifier.Classify("private task title"));
    }

    [TestMethod]
    public void UsesPerReportTokensInsteadOfDictionaryAttackableStableHashes()
    {
        const string raw = @"C:\Users\fixture\AppData\Local\Codex\Codex.exe";
        var firstReport = ProbeRedactor.Create();
        var secondReport = ProbeRedactor.Create();
        var sanitized = firstReport.Token(raw);

        Assert.AreEqual(64, sanitized.Length);
        Assert.IsFalse(sanitized.Contains("fixture", StringComparison.OrdinalIgnoreCase));
        Assert.AreEqual(sanitized, firstReport.Token(raw));
        Assert.AreNotEqual(sanitized, secondReport.Token(raw));
    }
}
