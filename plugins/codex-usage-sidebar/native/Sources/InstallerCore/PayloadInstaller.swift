import CryptoKit
import Darwin
import Foundation
import Security

public enum PayloadInstallerError: Error, Equatable {
    case unsafeDestination
    case missingManifest
    case invalidManifest
    case missingMarketplaceManifest
    case invalidMarketplaceManifest
    case versionMismatch(String)
    case missingControlScript
    case missingProvenance
    case invalidProvenance
    case missingCompanion
    case invalidCompanionSignature
    case companionDigestMismatch
    case lockUnavailable
}

public protocol PayloadInstalling {
    func install(from payloadRoot: URL, to paths: InstallerPaths) throws
}

public struct PayloadInstaller: PayloadInstalling {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func install(from payloadRoot: URL, to paths: InstallerPaths) throws {
        let sourceRoot = payloadRoot.standardizedFileURL
        let destination = paths.stableMarketplaceRoot.standardizedFileURL
        try validateDestination(paths: paths, destination: destination)
        try fileManager.createDirectory(
            at: paths.installRoot,
            withIntermediateDirectories: true
        )
        try validateDestination(paths: paths, destination: destination)

        let lock = try InstallerFileLock(
            url: paths.installRoot.appendingPathComponent(".installer.lock")
        )
        try withExtendedLifetime(lock) {
            try recoverInterruptedSwap(destination: destination, paths: paths)
            try validatePayload(at: sourceRoot)
            try replacePayload(sourceRoot, destination: destination, paths: paths)
        }
    }

    private func replacePayload(
        _ sourceRoot: URL,
        destination: URL,
        paths: InstallerPaths
    ) throws {
        let staging = paths.installRoot.appendingPathComponent(
            ".Marketplace.staging.\(UUID().uuidString)",
            isDirectory: true
        )
        let previous = paths.installRoot.appendingPathComponent(
            ".Marketplace.previous",
            isDirectory: true
        )
        defer { try? removeIfPresent(staging) }

        try fileManager.copyItem(at: sourceRoot, to: staging)
        try validatePayload(at: staging)
        if fileManager.fileExists(atPath: destination.path) {
            try removeIfPresent(previous)
            try fileManager.moveItem(at: destination, to: previous)
        }
        do {
            try fileManager.moveItem(at: staging, to: destination)
            try validatePayload(at: destination)
            try removeIfPresent(previous)
        } catch {
            try? removeIfPresent(destination)
            if fileManager.fileExists(atPath: previous.path) {
                try? fileManager.moveItem(at: previous, to: destination)
            }
            throw error
        }
    }

    private func recoverInterruptedSwap(
        destination: URL,
        paths: InstallerPaths
    ) throws {
        let previous = paths.installRoot.appendingPathComponent(
            ".Marketplace.previous",
            isDirectory: true
        )
        guard fileManager.fileExists(atPath: previous.path) else { return }
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.moveItem(at: previous, to: destination)
            return
        }
        do {
            try validatePayload(at: destination)
            try removeIfPresent(previous)
        } catch {
            try removeIfPresent(destination)
            try fileManager.moveItem(at: previous, to: destination)
        }
    }

    private func validateDestination(paths: InstallerPaths, destination: URL) throws {
        let expectedInstallRoot = paths.homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexUsageSidebar", isDirectory: true)
            .standardizedFileURL
        guard paths.installRoot.standardizedFileURL.path == expectedInstallRoot.path,
              destination.deletingLastPathComponent().standardizedFileURL.path ==
                expectedInstallRoot.path
        else {
            throw PayloadInstallerError.unsafeDestination
        }

        try rejectSymbolicLinks(
            from: paths.homeDirectory.standardizedFileURL,
            through: destination
        )
        let canonicalHome = paths.homeDirectory.resolvingSymlinksInPath().standardizedFileURL
        let canonicalExpected = canonicalHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexUsageSidebar", isDirectory: true)
            .appendingPathComponent("Marketplace", isDirectory: true)
            .standardizedFileURL
        let canonicalDestination = destination.resolvingSymlinksInPath().standardizedFileURL
        guard canonicalDestination.path == canonicalExpected.path else {
            throw PayloadInstallerError.unsafeDestination
        }
    }

    private func rejectSymbolicLinks(from base: URL, through target: URL) throws {
        let basePath = base.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        guard targetPath == basePath || targetPath.hasPrefix(basePath + "/") else {
            throw PayloadInstallerError.unsafeDestination
        }
        let suffix = targetPath.dropFirst(basePath.count)
        let components = suffix.split(separator: "/").map(String.init)
        var candidate = base.standardizedFileURL
        if isSymbolicLink(candidate) {
            throw PayloadInstallerError.unsafeDestination
        }
        for component in components {
            candidate.appendPathComponent(component)
            if isSymbolicLink(candidate) {
                throw PayloadInstallerError.unsafeDestination
            }
        }
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        var information = stat()
        guard lstat(url.path, &information) == 0 else { return false }
        return information.st_mode & S_IFMT == S_IFLNK
    }

    private func validatePayload(at root: URL) throws {
        let marketplaceURL = root.appendingPathComponent(
            ".agents/plugins/marketplace.json"
        )
        let plugin = root
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("codex-usage-sidebar", isDirectory: true)
        let manifestURL = plugin.appendingPathComponent(".codex-plugin/plugin.json")
        let control = plugin.appendingPathComponent("scripts/sidebar-control.sh")
        let provenanceURL = plugin.appendingPathComponent("assets/PROVENANCE.json")
        let companionApp = plugin.appendingPathComponent(
            "assets/Codex Usage Sidebar.app",
            isDirectory: true
        )
        let companionExecutable = companionApp.appendingPathComponent(
            "Contents/MacOS/CodexUsageSidebar"
        )
        guard fileManager.fileExists(atPath: marketplaceURL.path) else {
            throw PayloadInstallerError.missingMarketplaceManifest
        }
        let marketplace: EmbeddedMarketplaceManifest
        do {
            marketplace = try JSONDecoder().decode(
                EmbeddedMarketplaceManifest.self,
                from: Data(contentsOf: marketplaceURL)
            )
        } catch {
            throw PayloadInstallerError.invalidMarketplaceManifest
        }
        guard marketplace.name == InstallerCommandPlan.marketplaceName,
              marketplace.plugins.count == 1,
              marketplace.plugins[0].name == "codex-usage-sidebar",
              marketplace.plugins[0].source.source == "local",
              marketplace.plugins[0].source.path == "./plugins/codex-usage-sidebar"
        else {
            throw PayloadInstallerError.invalidMarketplaceManifest
        }
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PayloadInstallerError.missingManifest
        }
        guard fileManager.isExecutableFile(atPath: control.path) else {
            throw PayloadInstallerError.missingControlScript
        }
        let manifest: PluginManifest
        do {
            manifest = try JSONDecoder().decode(
                PluginManifest.self,
                from: Data(contentsOf: manifestURL)
            )
        } catch {
            throw PayloadInstallerError.invalidManifest
        }
        let baseVersion = manifest.version.split(separator: "+", maxSplits: 1).first.map(String.init)
        guard baseVersion == "0.3.0" else {
            throw PayloadInstallerError.versionMismatch(manifest.version)
        }
        guard fileManager.fileExists(atPath: provenanceURL.path) else {
            throw PayloadInstallerError.missingProvenance
        }
        let provenance: PayloadProvenance
        do {
            provenance = try JSONDecoder().decode(
                PayloadProvenance.self,
                from: Data(contentsOf: provenanceURL)
            )
        } catch {
            throw PayloadInstallerError.invalidProvenance
        }
        guard fileManager.isExecutableFile(atPath: companionExecutable.path) else {
            throw PayloadInstallerError.missingCompanion
        }
        guard hasValidSignature(companionApp) else {
            throw PayloadInstallerError.invalidCompanionSignature
        }
        let digest = SHA256.hash(data: try Data(contentsOf: companionExecutable))
            .map { String(format: "%02x", $0) }
            .joined()
        guard digest == provenance.companion.executableSha256.lowercased() else {
            throw PayloadInstallerError.companionDigestMismatch
        }
    }

    private func hasValidSignature(_ bundle: URL) -> Bool {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            bundle as CFURL,
            SecCSFlags(rawValue: 0),
            &staticCode
        )
        guard createStatus == errSecSuccess, let staticCode else { return false }
        return SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(
                rawValue: kSecCSCheckAllArchitectures |
                    kSecCSStrictValidate |
                    kSecCSCheckNestedCode
            ),
            nil
        ) == errSecSuccess
    }

    private func removeIfPresent(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

private final class InstallerFileLock {
    private let descriptor: Int32

    init(url: URL) throws {
        descriptor = open(url.path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0, flock(descriptor, LOCK_EX) == 0 else {
            if descriptor >= 0 { close(descriptor) }
            throw PayloadInstallerError.lockUnavailable
        }
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}

private struct PluginManifest: Decodable {
    let version: String
}

private struct EmbeddedMarketplaceManifest: Decodable {
    struct Plugin: Decodable {
        struct Source: Decodable {
            let source: String
            let path: String
        }

        let name: String
        let source: Source
    }

    let name: String
    let plugins: [Plugin]
}

private struct PayloadProvenance: Decodable {
    struct Companion: Decodable {
        let executableSha256: String
    }

    let companion: Companion
}
