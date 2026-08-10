import Foundation

public enum InstallerStep: Int, CaseIterable, Sendable {
    case check
    case install
    case authorizeCodex
    case accessibility
    case verify
}

public enum InstallerPhase: Equatable, Sendable {
    case ready
    case running(InstallerStep)
    case waiting(InstallerStep)
    case succeeded
    case failed(String)
}

public struct CommandSpec: Equatable, Sendable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]

    public init(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:]
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }
}
