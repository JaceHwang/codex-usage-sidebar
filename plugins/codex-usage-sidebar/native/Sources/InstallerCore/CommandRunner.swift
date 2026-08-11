import Foundation

public enum CommandRunnerError: Error, Equatable, Sendable {
    case timedOut
    case cancelled
}

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
    private let timeout: TimeInterval
    private let terminationGracePeriod: TimeInterval

    public init(
        timeout: TimeInterval = 120,
        terminationGracePeriod: TimeInterval = 1
    ) {
        self.timeout = timeout
        self.terminationGracePeriod = terminationGracePeriod
    }

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
        outputPipe.fileHandleForWriting.closeFile()
        errorPipe.fileHandleForWriting.closeFile()

        let output = PipeCapture()
        let errors = PipeCapture()
        let readers = DispatchGroup()
        read(outputPipe.fileHandleForReading, into: output, group: readers)
        read(errorPipe.fileHandleForReading, into: errors, group: readers)

        let deadline = Date().addingTimeInterval(timeout)
        var runnerError: CommandRunnerError?
        var readersFinished = false
        while process.isRunning || !readersFinished {
            if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) {
                runnerError = .cancelled
                break
            }
            if Date() >= deadline {
                runnerError = .timedOut
                break
            }
            if readersFinished {
                Thread.sleep(forTimeInterval: 0.01)
            } else {
                readersFinished = readers.wait(
                    timeout: .now() + .milliseconds(10)
                ) == .success
            }
        }
        if runnerError != nil {
            terminateAndReap(process)
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        } else {
            process.waitUntilExit()
            readers.wait()
        }
        if let runnerError {
            throw runnerError
        }

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: String(decoding: output.data, as: UTF8.self),
            standardError: String(decoding: errors.data, as: UTF8.self)
        )
    }

    private func read(
        _ handle: FileHandle,
        into capture: PipeCapture,
        group: DispatchGroup
    ) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            capture.store(handle.readDataToEndOfFile())
            group.leave()
        }
    }

    private func terminateAndReap(_ process: Process) {
        if process.isRunning {
            process.terminate()
        }
        let graceDeadline = Date().addingTimeInterval(terminationGracePeriod)
        while process.isRunning && Date() < graceDeadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }
}

private final class PipeCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.withLock { storage }
    }

    func store(_ data: Data) {
        lock.withLock { storage = data }
    }
}
