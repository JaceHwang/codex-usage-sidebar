namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class DiagnosticSanitizerTests
{
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
