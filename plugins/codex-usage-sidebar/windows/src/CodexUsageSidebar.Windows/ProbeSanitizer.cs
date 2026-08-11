using System.Security.Cryptography;
using System.Text;

namespace CodexUsageSidebar.Windows;

public static class ProbeSanitizer
{
    public static string PathIdentity(string path)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(path))).ToLowerInvariant();
    }

    public static string TextIdentity(string text) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text ?? string.Empty))).ToLowerInvariant();
}
