using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;

namespace CodexUsageSidebar.Installer;

public sealed class EmbeddedPayloadSource
{
    private const string ManifestName = "windows-payload.json";
    private readonly IReadOnlyDictionary<string, string> resourceNames;
    private readonly Func<string, Stream> openResource;
    private readonly string trustedManifestSha256;

    public EmbeddedPayloadSource(
        IEnumerable<string> resourceNames,
        Func<string, Stream> openResource,
        string trustedManifestSha256)
    {
        ArgumentNullException.ThrowIfNull(resourceNames);
        ArgumentNullException.ThrowIfNull(openResource);
        if (!IsLowerHex(trustedManifestSha256, 64))
        {
            throw new ArgumentException(
                "The embedded payload manifest digest must be lowercase SHA-256.",
                nameof(trustedManifestSha256));
        }

        var normalized = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var original in resourceNames)
        {
            var relative = NormalizeRelativePath(original);
            if (!normalized.TryAdd(relative, original))
            {
                throw new InvalidDataException("The embedded payload contains duplicate resource names.");
            }
        }
        this.resourceNames = normalized;
        this.openResource = openResource;
        this.trustedManifestSha256 = trustedManifestSha256;
    }

    public static EmbeddedPayloadSource FromAssembly(
        Assembly assembly,
        string resourcePrefix,
        string trustedManifestSha256)
    {
        ArgumentNullException.ThrowIfNull(assembly);
        ArgumentException.ThrowIfNullOrWhiteSpace(resourcePrefix);
        var manifestNames = assembly.GetManifestResourceNames()
            .Where(name => name.StartsWith(resourcePrefix, StringComparison.Ordinal))
            .ToArray();
        var relativeNames = manifestNames.Select(name => name[resourcePrefix.Length..]).ToArray();
        var fullNames = relativeNames.Zip(manifestNames).ToDictionary(
            pair => pair.First,
            pair => pair.Second,
            StringComparer.Ordinal);
        return new EmbeddedPayloadSource(
            relativeNames,
            relative => assembly.GetManifestResourceStream(fullNames[relative])
                ?? throw new InvalidDataException($"Missing embedded payload resource: {relative}"),
            trustedManifestSha256);
    }

    public EmbeddedPayloadLease Extract(string privateStageParent)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(privateStageParent);
        var parent = Path.GetFullPath(privateStageParent);
        EnsureExistingAncestorsAreNotReparsePoints(parent);
        Directory.CreateDirectory(parent);
        EnsureNotReparsePoint(parent);

        var stage = Path.Combine(parent, ".cus-embedded-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stage);
        try
        {
            EnsureNotReparsePoint(stage);
            var manifestBytes = ReadResource(ManifestName);
            var actualManifestSha256 = Convert.ToHexString(SHA256.HashData(manifestBytes)).ToLowerInvariant();
            if (!string.Equals(actualManifestSha256, trustedManifestSha256, StringComparison.Ordinal))
            {
                throw new InvalidDataException("The embedded payload manifest is not trusted by this installer.");
            }

            var declaredFiles = ParseDeclaredFiles(manifestBytes);
            var expectedResources = declaredFiles.Keys.Append(ManifestName).ToHashSet(StringComparer.Ordinal);
            if (!expectedResources.SetEquals(resourceNames.Keys))
            {
                throw new InvalidDataException("Embedded payload resources do not exactly match the trusted manifest.");
            }

            WriteFile(stage, ManifestName, manifestBytes);
            foreach (var (relative, expectedSha256) in declaredFiles)
            {
                var contents = ReadResource(relative);
                var actualSha256 = Convert.ToHexString(SHA256.HashData(contents)).ToLowerInvariant();
                if (!string.Equals(actualSha256, expectedSha256, StringComparison.Ordinal))
                {
                    throw new InvalidDataException($"Embedded payload digest mismatch: {relative}");
                }
                WriteFile(stage, relative, contents);
            }

            AtomicPayloadInstaller.ValidateNoLinks(stage);
            return new EmbeddedPayloadLease(stage);
        }
        catch
        {
            TryDelete(stage);
            throw;
        }
    }

    private byte[] ReadResource(string relative)
    {
        if (!resourceNames.TryGetValue(relative, out var original))
        {
            throw new InvalidDataException($"Missing embedded payload resource: {relative}");
        }
        using var source = openResource(original);
        using var destination = new MemoryStream();
        source.CopyTo(destination);
        return destination.ToArray();
    }

    private static Dictionary<string, string> ParseDeclaredFiles(byte[] manifestBytes)
    {
        try
        {
            using var document = JsonDocument.Parse(manifestBytes);
            if (!document.RootElement.TryGetProperty("files", out var files)
                || files.ValueKind != JsonValueKind.Object)
            {
                throw new InvalidDataException("The embedded payload manifest must declare file digests.");
            }

            var declared = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var property in files.EnumerateObject())
            {
                var relative = NormalizeRelativePath(property.Name);
                var digest = property.Value.ValueKind == JsonValueKind.String
                    ? property.Value.GetString()
                    : null;
                if (digest is null || !IsLowerHex(digest, 64))
                {
                    throw new InvalidDataException("The embedded payload manifest contains an invalid SHA-256 digest.");
                }
                if (string.Equals(relative, ManifestName, StringComparison.Ordinal)
                    || !declared.TryAdd(relative, digest))
                {
                    throw new InvalidDataException("The embedded payload manifest contains a duplicate or reserved path.");
                }
            }
            if (declared.Count == 0)
            {
                throw new InvalidDataException("The embedded payload manifest cannot be empty.");
            }
            return declared;
        }
        catch (JsonException error)
        {
            throw new InvalidDataException("The embedded payload manifest is invalid.", error);
        }
    }

    private static void WriteFile(string root, string relative, byte[] contents)
    {
        var platformRelative = relative.Replace('/', Path.DirectorySeparatorChar);
        var destination = Path.GetFullPath(Path.Combine(root, platformRelative));
        var normalizedRoot = root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        if (!destination.StartsWith(normalizedRoot, comparison))
        {
            throw new InvalidDataException("An embedded payload path escapes its private stage.");
        }
        var directory = Path.GetDirectoryName(destination)
            ?? throw new InvalidDataException("An embedded payload file must have a parent directory.");
        Directory.CreateDirectory(directory);
        EnsureNotReparsePoint(directory);
        using var stream = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        stream.Write(contents);
        stream.Flush(flushToDisk: true);
    }

    private static string NormalizeRelativePath(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || Path.IsPathRooted(value))
        {
            throw new InvalidDataException("The embedded payload contains an unsafe resource path.");
        }
        var normalized = value.Replace('\\', '/');
        if (normalized.Split('/').Any(segment => segment is "" or "." or ".."))
        {
            throw new InvalidDataException("The embedded payload contains an unsafe resource path.");
        }
        return normalized;
    }

    private static void EnsureExistingAncestorsAreNotReparsePoints(string path)
    {
        for (var current = new DirectoryInfo(path); current is not null; current = current.Parent)
        {
            if (current.Exists) EnsureNotReparsePoint(current.FullName);
        }
    }

    private static void EnsureNotReparsePoint(string path)
    {
        if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
        {
            throw new InvalidDataException("The embedded payload stage cannot traverse links or reparse points.");
        }
    }

    private static bool IsLowerHex(string value, int length) =>
        value.Length == length && value.All(character =>
            character is >= '0' and <= '9' or >= 'a' and <= 'f');

    private static void TryDelete(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}

public sealed class EmbeddedPayloadLease : IDisposable
{
    private string? payloadDirectory;

    internal EmbeddedPayloadLease(string payloadDirectory)
    {
        this.payloadDirectory = payloadDirectory;
    }

    public string PayloadDirectory => payloadDirectory
        ?? throw new ObjectDisposedException(nameof(EmbeddedPayloadLease));

    public void Dispose()
    {
        var path = Interlocked.Exchange(ref payloadDirectory, null);
        if (path is not null && Directory.Exists(path))
        {
            Directory.Delete(path, recursive: true);
        }
    }
}
