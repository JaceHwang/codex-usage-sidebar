namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class DiagnosticSanitizerTests
{
    [TestMethod]
    public void HashesExecutablePathInsteadOfLeakingTheUserProfile()
    {
        const string raw = @"C:\Users\fixture\AppData\Local\Codex\Codex.exe";
        var sanitized = ProbeSanitizer.PathIdentity(raw);

        Assert.AreEqual(64, sanitized.Length);
        Assert.IsFalse(sanitized.Contains("fixture", StringComparison.OrdinalIgnoreCase));
        Assert.AreEqual(sanitized, ProbeSanitizer.PathIdentity(raw));
    }
}
