using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed record AppServerLaunchPlan(
    string Executable,
    IReadOnlyList<string> Arguments,
    IReadOnlyDictionary<string, string> Environment)
{
    public static AppServerLaunchPlan Create(string executable, string isolatedCodexHome)
    {
        if (!IsAbsoluteWindowsPath(executable))
        {
            throw new ArgumentException("The Codex executable must be an absolute Windows path.", nameof(executable));
        }
        if (!IsAbsoluteWindowsPath(isolatedCodexHome))
        {
            throw new ArgumentException("The isolated Codex home must be an absolute Windows path.", nameof(isolatedCodexHome));
        }

        return new AppServerLaunchPlan(
            executable,
            new[] { "app-server", "--stdio" },
            new ReadOnlyDictionary<string, string>(new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["CODEX_HOME"] = isolatedCodexHome,
            }));
    }

    private static bool IsAbsoluteWindowsPath(string value) =>
        value.Length >= 3
        && char.IsAsciiLetter(value[0])
        && value[1] == ':'
        && value[2] is '\\' or '/'
        && value.IndexOfAny(['\0', '"']) < 0;
}

public sealed class AppServerProcessConnectionFactory(AppServerLaunchPlan plan) : IJsonLineConnectionFactory
{
    public ValueTask<IJsonLineConnection> ConnectAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var startInfo = new ProcessStartInfo
        {
            FileName = plan.Executable,
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        foreach (var argument in plan.Arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }
        foreach (var (name, value) in plan.Environment)
        {
            startInfo.Environment[name] = value;
        }
        var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        if (!process.Start())
        {
            process.Dispose();
            throw new InvalidOperationException("Codex app-server did not start.");
        }
        return ValueTask.FromResult<IJsonLineConnection>(new ProcessJsonLineConnection(process));
    }
}

internal sealed class ProcessJsonLineConnection : IJsonLineConnection
{
    private const int StandardErrorTailCapacity = 4_000;
    private readonly Process process;
    private readonly BoundedTextCapture standardError = new(StandardErrorTailCapacity);
    private readonly Task standardErrorDrain;

    internal ProcessJsonLineConnection(Process process)
    {
        this.process = process;
        standardErrorDrain = DrainStandardErrorAsync(process.StandardError, standardError);
    }

    internal string StandardErrorTail => standardError.Value;
    internal bool StandardErrorWasTruncated => standardError.WasTruncated;

    public async ValueTask WriteLineAsync(string line, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        await process.StandardInput.WriteLineAsync(line.AsMemory(), cancellationToken).ConfigureAwait(false);
        await process.StandardInput.FlushAsync(cancellationToken).ConfigureAwait(false);
    }

    public async IAsyncEnumerable<string> ReadLinesAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        while (await process.StandardOutput.ReadLineAsync(cancellationToken).ConfigureAwait(false) is { } line)
        {
            yield return line;
        }
        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
        if (process.ExitCode != 0)
        {
            await standardErrorDrain.WaitAsync(cancellationToken).ConfigureAwait(false);
            var error = standardError.Value;
            if (standardError.WasTruncated) error = "…" + error;
            throw new InvalidOperationException($"Codex app-server exited with code {process.ExitCode}: {error}");
        }
    }

    public async ValueTask DisposeAsync()
    {
        process.StandardInput.Close();
        if (!process.HasExited)
        {
            process.Kill(entireProcessTree: true);
        }
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        try
        {
            await process.WaitForExitAsync(timeout.Token).ConfigureAwait(false);
            await standardErrorDrain.WaitAsync(timeout.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
        }
        process.Dispose();
    }

    private static async Task DrainStandardErrorAsync(
        StreamReader reader,
        BoundedTextCapture capture)
    {
        var buffer = new char[1_024];
        int count;
        while ((count = await reader.ReadAsync(buffer.AsMemory()).ConfigureAwait(false)) > 0)
        {
            capture.Append(buffer.AsSpan(0, count));
        }
    }
}

internal sealed class BoundedTextCapture
{
    private readonly int capacity;
    private readonly object gate = new();
    private readonly StringBuilder buffer;
    private bool wasTruncated;

    internal BoundedTextCapture(int capacity)
    {
        if (capacity <= 0) throw new ArgumentOutOfRangeException(nameof(capacity));
        this.capacity = capacity;
        buffer = new StringBuilder(capacity);
    }

    internal bool WasTruncated
    {
        get { lock (gate) return wasTruncated; }
    }

    internal string Value
    {
        get { lock (gate) return buffer.ToString(); }
    }

    internal void Append(ReadOnlySpan<char> value)
    {
        lock (gate)
        {
            if (value.Length >= capacity)
            {
                buffer.Clear();
                buffer.Append(value[^capacity..]);
                wasTruncated = true;
                return;
            }

            var overflow = buffer.Length + value.Length - capacity;
            if (overflow > 0)
            {
                buffer.Remove(0, overflow);
                wasTruncated = true;
            }
            buffer.Append(value);
        }
    }
}
