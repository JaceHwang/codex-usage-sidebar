import Foundation

public struct CommandResult: Equatable, Sendable {
    public let terminationStatus: Int32
    public let standardOutput: String
    public let standardError: String

    public init(
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String
    ) {
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var succeeded: Bool {
        terminationStatus == 0
    }

    public func environmentValue(named name: String) -> String? {
        standardOutput
            .split(whereSeparator: { $0.isNewline })
            .first { $0.hasPrefix("\(name)=") }
            .map { String($0.dropFirst(name.count + 1)) }
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: CommandSpec) throws -> CommandResult
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(_ command: CommandSpec) throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = command.executable
        process.arguments = command.arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment.merging(
            command.environment,
            uniquingKeysWith: { _, explicitValue in explicitValue }
        )

        try process.run()
        process.waitUntilExit()

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: String(
                decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            ),
            standardError: String(
                decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
        )
    }
}
