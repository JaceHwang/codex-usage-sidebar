if (args is ["stderr-flood"])
{
    Console.Error.Write(new string('e', 2_000_000));
    Console.Error.Flush();
    Console.Out.WriteLine("ready");
    Console.Out.Flush();
    _ = Console.In.ReadLine();
    return;
}

Console.Error.WriteLine("Unknown process fixture mode.");
Environment.ExitCode = 64;

public sealed class ProcessFixtureMarker { }
