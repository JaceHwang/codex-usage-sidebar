import Foundation

public enum PayloadInstallerError: Error, Equatable {
    case unsafeDestination
    case missingManifest
    case invalidManifest
    case versionMismatch(String)
    case missingControlScript
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
        guard destination.deletingLastPathComponent() == paths.installRoot.standardizedFileURL else {
            throw PayloadInstallerError.unsafeDestination
        }

        let sourcePlugin = sourceRoot
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("codex-usage-sidebar", isDirectory: true)
        let sourceManifest = sourcePlugin
            .appendingPathComponent(".codex-plugin", isDirectory: true)
            .appendingPathComponent("plugin.json", isDirectory: false)
        let sourceControl = sourcePlugin
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("sidebar-control.sh", isDirectory: false)
        guard fileManager.fileExists(atPath: sourceManifest.path) else {
            throw PayloadInstallerError.missingManifest
        }
        guard fileManager.isExecutableFile(atPath: sourceControl.path) else {
            throw PayloadInstallerError.missingControlScript
        }

        let manifest: PluginManifest
        do {
            manifest = try JSONDecoder().decode(
                PluginManifest.self,
                from: Data(contentsOf: sourceManifest)
            )
        } catch {
            throw PayloadInstallerError.invalidManifest
        }
        let baseVersion = manifest.version.split(separator: "+", maxSplits: 1).first.map(String.init)
        guard baseVersion == "0.2.3" else {
            throw PayloadInstallerError.versionMismatch(manifest.version)
        }

        try fileManager.createDirectory(
            at: paths.installRoot,
            withIntermediateDirectories: true
        )
        let temporary = paths.installRoot.appendingPathComponent(
            ".Marketplace.tmp",
            isDirectory: true
        )
        let previous = paths.installRoot.appendingPathComponent(
            ".Marketplace.previous",
            isDirectory: true
        )
        try removeIfPresent(temporary)
        try removeIfPresent(previous)
        try fileManager.copyItem(at: sourceRoot, to: temporary)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.moveItem(at: destination, to: previous)
        }
        do {
            try fileManager.moveItem(at: temporary, to: destination)
            try removeIfPresent(previous)
        } catch {
            try? removeIfPresent(temporary)
            if fileManager.fileExists(atPath: previous.path),
               !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.moveItem(at: previous, to: destination)
            }
            throw error
        }
    }

    private func removeIfPresent(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

private struct PluginManifest: Decodable {
    let version: String
}
