import Foundation

/// Locates the Codex CLI without tying installation to one package manager or
/// one historical install path. The installer deliberately does not compare a
/// Codex version: compatibility is determined by the plugin commands the CLI
/// exposes when those commands are executed.
public enum CodexExecutableLocator {
    public static let defaultStandardCandidates = [
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
        "/usr/bin/codex",
    ]

    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        standardCandidates: [String] = defaultStandardCandidates
    ) -> URL? {
        let candidates = standardCandidates + pathCandidates(environment: environment)
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
    }

    private static func pathCandidates(environment: [String: String]) -> [String] {
        guard let path = environment["PATH"], !path.isEmpty else { return [] }
        return path.split(separator: ":", omittingEmptySubsequences: true)
            .map { String($0) }
            .map { URL(fileURLWithPath: $0).appendingPathComponent("codex").path }
    }
}
