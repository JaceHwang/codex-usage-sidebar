using System.Security.Cryptography;
using System.Text;

namespace CodexUsageSidebar.Windows;

public sealed class ProbeRedactor
{
    private readonly byte[] key;

    private ProbeRedactor(byte[] key) => this.key = key;

    public static ProbeRedactor Create() => new(RandomNumberGenerator.GetBytes(32));

    public string Token(string value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return Convert.ToHexString(HMACSHA256.HashData(key, Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    }
}
