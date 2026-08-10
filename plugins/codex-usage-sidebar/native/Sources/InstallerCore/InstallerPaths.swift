import Foundation

public struct InstallerPaths: Equatable, Sendable {
    public let homeDirectory: URL
    public let payloadRoot: URL
    public let codexExecutable: URL

    public init(
        homeDirectory: URL,
        payloadRoot: URL,
        codexExecutable: URL
    ) {
        self.homeDirectory = homeDirectory.standardizedFileURL
        self.payloadRoot = payloadRoot.standardizedFileURL
        self.codexExecutable = codexExecutable.standardizedFileURL
    }

    public var installRoot: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexUsageSidebar", isDirectory: true)
    }

    public var stableMarketplaceRoot: URL {
        installRoot.appendingPathComponent("Marketplace", isDirectory: true)
    }

    public var pluginRoot: URL {
        stableMarketplaceRoot
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("codex-usage-sidebar", isDirectory: true)
    }

    public var pluginManifest: URL {
        pluginRoot
            .appendingPathComponent(".codex-plugin", isDirectory: true)
            .appendingPathComponent("plugin.json", isDirectory: false)
    }

    public var controlScript: URL {
        pluginRoot
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("sidebar-control.sh", isDirectory: false)
    }

    public var installedControlScript: URL {
        installRoot.appendingPathComponent("sidebar-control.sh", isDirectory: false)
    }

    public var pluginData: URL {
        installRoot.appendingPathComponent("Data", isDirectory: true)
    }

    public var codexHome: URL {
        installRoot.appendingPathComponent("CodexHome", isDirectory: true)
    }

    public var runtimeState: URL {
        pluginData.appendingPathComponent("runtime-state.txt", isDirectory: false)
    }
}
