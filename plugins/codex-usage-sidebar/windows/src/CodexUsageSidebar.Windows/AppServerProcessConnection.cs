using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;
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

internal sealed class ProcessJsonLineConnection(Process process) : IJsonLineConnection
{
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
            var error = await process.StandardError.ReadToEndAsync(cancellationToken).ConfigureAwait(false);
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
        }
        catch (OperationCanceledException)
        {
        }
        process.Dispose();
    }
}
