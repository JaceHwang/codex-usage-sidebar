import Darwin
import XCTest
@testable import InstallerCore

final class CommandRunnerTests: XCTestCase {
    func testRunnerCapturesArgumentsOutputAndExitStatus() throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["%s", "installer-ready"]
        )

        let result = try ProcessCommandRunner().run(command)

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.standardOutput, "installer-ready")
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.succeeded)
    }

    func testRunnerMergesOnlyExplicitEnvironmentValues() throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [],
            environment: ["CUS_INSTALLER_TEST_VALUE": "isolated-home"]
        )

        let result = try ProcessCommandRunner().run(command)

        XCTAssertTrue(result.standardOutput.contains("CUS_INSTALLER_TEST_VALUE=isolated-home"))
        XCTAssertNotNil(result.environmentValue(named: "PATH"))
    }

    func testRunnerDrainsLargeStandardOutputAndErrorWhileChildRuns() throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                "import os; os.write(1, b'o' * 262144); os.write(2, b'e' * 262144)",
            ]
        )

        let result = try ProcessCommandRunner(timeout: 5).run(command)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.standardOutput.utf8.count, 262_144)
        XCTAssertEqual(result.standardError.utf8.count, 262_144)
    }

    func testRunnerTerminatesAndReapsAHangingChildAtTimeout() throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(30)",
            ]
        )
        let started = Date()

        XCTAssertThrowsError(
            try ProcessCommandRunner(timeout: 0.2, terminationGracePeriod: 0.1).run(command)
        ) { error in
            XCTAssertEqual(error as? CommandRunnerError, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testRunnerTerminatesAndReapsAChildWhenTaskIsCancelled() async throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-c", "import time; time.sleep(30)"]
        )
        let task = Task.detached {
            try ProcessCommandRunner(timeout: 30, terminationGracePeriod: 0.1).run(command)
        }
        try await Task.sleep(for: .milliseconds(100))

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("cancelled command unexpectedly completed")
        } catch {
            XCTAssertEqual(error as? CommandRunnerError, .cancelled)
        }
    }

    func testRunnerDoesNotWaitForDescendantsHoldingPipesAfterTimeout() throws {
        let command = descendantHoldingPipesCommand()
        let started = Date()

        XCTAssertThrowsError(
            try ProcessCommandRunner(timeout: 0.2, terminationGracePeriod: 0.1).run(command)
        ) { error in
            XCTAssertEqual(error as? CommandRunnerError, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testRunnerDoesNotWaitForDescendantsHoldingPipesAfterCancellation() async throws {
        let command = descendantHoldingPipesCommand()
        let task = Task.detached {
            try ProcessCommandRunner(timeout: 30, terminationGracePeriod: 0.1)
                .run(command)
        }
        try await Task.sleep(for: .milliseconds(100))
        let cancelled = Date()

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("cancelled command unexpectedly completed")
        } catch {
            XCTAssertEqual(error as? CommandRunnerError, .cancelled)
        }
        XCTAssertLessThan(Date().timeIntervalSince(cancelled), 2)
    }

    func testRunnerBoundsPipeDrainAfterParentExitsBeforeTimeout() throws {
        let command = descendantHoldingPipesCommand(parentKeepsRunning: false)
        let started = Date()

        XCTAssertThrowsError(
            try ProcessCommandRunner(timeout: 0.2, terminationGracePeriod: 0.1).run(command)
        ) { error in
            XCTAssertEqual(error as? CommandRunnerError, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testRunnerCancelsPipeDrainAfterParentHasExited() async throws {
        let command = descendantHoldingPipesCommand(parentKeepsRunning: false)
        let task = Task.detached {
            try ProcessCommandRunner(timeout: 30, terminationGracePeriod: 0.1).run(command)
        }
        try await Task.sleep(for: .milliseconds(100))
        let cancelled = Date()

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("cancelled pipe drain unexpectedly completed")
        } catch {
            XCTAssertEqual(error as? CommandRunnerError, .cancelled)
        }
        XCTAssertLessThan(Date().timeIntervalSince(cancelled), 2)
    }

    func testRunnerDoesNotBusySpinAfterChildClosesBothOutputPipes() throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                "import os,time; os.close(1); os.close(2); time.sleep(5)",
            ]
        )
        let cpuStarted = clock()

        XCTAssertThrowsError(
            try ProcessCommandRunner(timeout: 0.5, terminationGracePeriod: 0.1).run(command)
        ) { error in
            XCTAssertEqual(error as? CommandRunnerError, .timedOut)
        }
        let cpuSeconds = Double(clock() - cpuStarted) / Double(CLOCKS_PER_SEC)
        XCTAssertLessThan(cpuSeconds, 0.15)
    }

    private func descendantHoldingPipesCommand(
        parentKeepsRunning: Bool = true
    ) -> CommandSpec {
        let parentDelay = parentKeepsRunning ? "; time.sleep(5)" : ""
        return CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import signal,time; signal.signal(signal.SIGHUP,signal.SIG_IGN); signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(5)'], start_new_session=True)\(parentDelay)",
            ]
        )
    }
}
