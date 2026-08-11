using System.Text.Json;
using System.Security.Cryptography;

namespace CodexUsageSidebar.Installer;

public sealed class AtomicPayloadInstaller
{
    private const string ManifestName = "windows-payload.json";

    public void Install(string source, string destination, string expectedVersion)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(expectedVersion);
        var sourcePath = Path.GetFullPath(source);
        var destinationPath = Path.GetFullPath(destination);
        if (!Directory.Exists(sourcePath))
        {
            throw new DirectoryNotFoundException(sourcePath);
        }
        if (IsSameOrDescendant(destinationPath, sourcePath))
        {
            throw new InvalidDataException("The destination cannot be inside the source payload.");
        }

        ValidateNoLinks(sourcePath);
        if (OperatingSystem.IsWindows())
        {
            ValidateExistingAncestors(Path.GetDirectoryName(destinationPath)!);
        }
        ValidateManifest(sourcePath, expectedVersion);

        var parent = Path.GetDirectoryName(destinationPath)
            ?? throw new InvalidDataException("The destination must have a parent directory.");
        Directory.CreateDirectory(parent);
        var operationId = Guid.NewGuid().ToString("N");
        var temporary = Path.Combine(parent, ".cus-stage-" + operationId);
        var backup = Path.Combine(parent, ".cus-backup-" + operationId);
        var lockPath = Path.Combine(parent, ".cus-install.lock");

        using var installLock = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        var movedPrevious = false;
        var activated = false;
        try
        {
            CopyDirectory(sourcePath, temporary);
            if (Directory.Exists(destinationPath))
            {
                Directory.Move(destinationPath, backup);
                movedPrevious = true;
            }
            Directory.Move(temporary, destinationPath);
            activated = true;
            if (movedPrevious)
            {
                Directory.Delete(backup, recursive: true);
                movedPrevious = false;
            }
        }
        catch
        {
            if (activated && Directory.Exists(destinationPath))
            {
                Directory.Delete(destinationPath, recursive: true);
            }
            if (movedPrevious && Directory.Exists(backup))
            {
                Directory.Move(backup, destinationPath);
            }
            throw;
        }
        finally
        {
            if (Directory.Exists(temporary)) Directory.Delete(temporary, recursive: true);
            if (Directory.Exists(backup) && !movedPrevious) Directory.Delete(backup, recursive: true);
        }
        installLock.Dispose();
        File.Delete(lockPath);
    }

    private static void ValidateManifest(string source, string expectedVersion)
    {
        var manifestPath = Path.Combine(source, ManifestName);
        if (!File.Exists(manifestPath))
        {
            throw new InvalidDataException($"Missing {ManifestName}.");
        }
        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(manifestPath));
            var root = document.RootElement;
            if (!root.TryGetProperty("version", out var version)
                || version.ValueKind != JsonValueKind.String
                || !string.Equals(version.GetString(), expectedVersion, StringComparison.Ordinal))
            {
                throw new InvalidDataException("The Windows payload version does not match the installer.");
            }
            if (!root.TryGetProperty("architecture", out var architecture)
                || architecture.ValueKind != JsonValueKind.String
                || architecture.GetString() != "x64")
            {
                throw new InvalidDataException("The Windows beta payload must declare the x64 architecture.");
            }
            if (!root.TryGetProperty("files", out var files) || files.ValueKind != JsonValueKind.Object)
            {
                throw new InvalidDataException("The Windows payload manifest must contain file digests.");
            }

            var declared = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var property in files.EnumerateObject())
            {
                var relative = property.Name.Replace('/', Path.DirectorySeparatorChar);
                if (Path.IsPathRooted(relative) || relative.Split(Path.DirectorySeparatorChar).Any(x => x is "" or "." or ".."))
                {
                    throw new InvalidDataException("The Windows payload manifest contains an unsafe file path.");
                }
                var digest = property.Value.ValueKind == JsonValueKind.String ? property.Value.GetString() : null;
                if (digest is null || digest.Length != 64 || !digest.All(Uri.IsHexDigit))
                {
                    throw new InvalidDataException("The Windows payload manifest contains an invalid SHA-256 digest.");
                }
                var filePath = Path.GetFullPath(Path.Combine(source, relative));
                if (!IsSameOrDescendant(filePath, source) || !File.Exists(filePath))
                {
                    throw new InvalidDataException("A declared Windows payload file is missing or outside the payload.");
                }
                using var stream = File.OpenRead(filePath);
                var actual = Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
                if (!string.Equals(actual, digest, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidDataException($"Windows payload digest mismatch: {property.Name}");
                }
                declared.Add(Path.GetRelativePath(source, filePath));
            }

            var actualFiles = Directory.EnumerateFiles(source, "*", SearchOption.AllDirectories)
                .Select(path => Path.GetRelativePath(source, path))
                .Where(path => !string.Equals(path, ManifestName, StringComparison.OrdinalIgnoreCase))
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            if (declared.Count == 0 || !declared.SetEquals(actualFiles))
            {
                throw new InvalidDataException("Every Windows payload file must have exactly one manifest digest.");
            }
        }
        catch (JsonException error)
        {
            throw new InvalidDataException("The Windows payload manifest is invalid.", error);
        }
    }

    private static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);
        foreach (var file in Directory.EnumerateFiles(source))
        {
            File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), overwrite: false);
        }
        foreach (var directory in Directory.EnumerateDirectories(source))
        {
            CopyDirectory(directory, Path.Combine(destination, Path.GetFileName(directory)));
        }
    }

    private static void ValidateNoLinks(string root)
    {
        foreach (var path in Directory.EnumerateFileSystemEntries(root, "*", SearchOption.AllDirectories).Prepend(root))
        {
            if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("The Windows payload cannot contain links or reparse points.");
            }
        }
    }

    private static void ValidateExistingAncestors(string path)
    {
        for (var current = new DirectoryInfo(path); current is not null; current = current.Parent)
        {
            if (!current.Exists) continue;
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("The install path cannot traverse a link or reparse point.");
            }
        }
    }

    private static bool IsSameOrDescendant(string candidate, string ancestor)
    {
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        var normalizedAncestor = ancestor.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return string.Equals(candidate.TrimEnd(Path.DirectorySeparatorChar), ancestor.TrimEnd(Path.DirectorySeparatorChar), comparison)
            || candidate.StartsWith(normalizedAncestor, comparison);
    }
}
