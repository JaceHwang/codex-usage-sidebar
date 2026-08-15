namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class CodexProcessIdentityTests
{
    [TestMethod]
    public void AcceptsConfirmedCodexHostIdentities()
    {
        Assert.IsFalse(CodexProcessIdentity.IsSupported("Codex", null, null));
        Assert.IsTrue(CodexProcessIdentity.IsSupported(
            "ChatGPT",
            "Codex",
            "OpenAI OpCo, LLC",
            @"C:\Program Files\WindowsApps\OpenAI.Codex_26.803.10989.0_x64__2p2nqsd0c76g0\app\ChatGPT.exe",
            @"C:\Program Files\WindowsApps"));
    }

    [DataTestMethod]
    [DataRow("ChatGPT", "ChatGPT", "OpenAI OpCo, LLC")]
    [DataRow("ChatGPT", "Codex", "Example Corp")]
    [DataRow("Other", "Codex", "OpenAI OpCo, LLC")]
    public void RejectsUnconfirmedHostIdentities(
        string processName,
        string productName,
        string companyName)
    {
        Assert.IsFalse(CodexProcessIdentity.IsSupported(
            processName,
            productName,
            companyName));
    }

    [TestMethod]
    public void RejectsMatchingMetadataOutsideTheProtectedCodexPackagePath()
    {
        Assert.IsFalse(CodexProcessIdentity.IsSupported(
            "ChatGPT",
            "Codex",
            "OpenAI OpCo, LLC",
            @"C:\Users\fixture\ChatGPT.exe",
            @"C:\Program Files\WindowsApps"));
    }
}
