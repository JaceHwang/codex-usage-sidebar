import Foundation

public struct CompanionRuntimeConfiguration: Equatable, Sendable {
    public let pluginDataURL: URL

    public var codexHomeURL: URL {
        pluginDataURL
            .deletingLastPathComponent()
            .appendingPathComponent("CodexHome", isDirectory: true)
    }

    public init(arguments: [String], userHomeURL: URL) {
        let defaultDataURL = userHomeURL
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent("CodexUsageSidebar", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)

        if
            let flagIndex = arguments.firstIndex(of: "--plugin-data"),
            arguments.indices.contains(flagIndex + 1),
            !arguments[flagIndex + 1].isEmpty
        {
            pluginDataURL = URL(
                fileURLWithPath: arguments[flagIndex + 1],
                isDirectory: true
            ).standardizedFileURL
        } else {
            pluginDataURL = defaultDataURL.standardizedFileURL
        }
    }
}
