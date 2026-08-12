using System.Security.Cryptography;
using System.Text;

namespace CodexUsageSidebar.Windows;

public sealed class PerUserHostSingleton : IDisposable
{
    private Mutex? mutex;

    private PerUserHostSingleton(Mutex mutex) => this.mutex = mutex;

    public static PerUserHostSingleton? TryAcquire(string userIdentity)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userIdentity);
        var identityHash = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(userIdentity)));
        var mutex = new Mutex(
            initiallyOwned: true,
            $@"Local\CodexUsageSidebar.Windows.{identityHash}",
            out var createdNew);
        if (createdNew) return new PerUserHostSingleton(mutex);
        mutex.Dispose();
        return null;
    }

    public void Dispose()
    {
        var owned = Interlocked.Exchange(ref mutex, null);
        if (owned is null) return;
        owned.ReleaseMutex();
        owned.Dispose();
    }
}
