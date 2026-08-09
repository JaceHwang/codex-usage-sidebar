import Foundation
import XCTest
@testable import SidebarCore

final class JSONRPCTests: XCTestCase {
    func testRequestIDsIncrease() {
        var sequencer = JSONRPCSequencer()

        XCTAssertEqual(sequencer.nextRequestID(), 1)
        XCTAssertEqual(sequencer.nextRequestID(), 2)
        XCTAssertEqual(sequencer.nextRequestID(), 3)
    }

    func testPartialLinesBufferUntilNewline() {
        var buffer = LineBuffer()

        XCTAssertEqual(buffer.append(Data(#"{"id":1"#.utf8)), [])
        XCTAssertEqual(buffer.append(Data("}\n".utf8)), [#"{"id":1}"#])
    }

    func testMultipleLinesAreEmittedSeparately() {
        var buffer = LineBuffer()

        let lines = buffer.append(Data("{\"id\":1}\n{\"id\":2}\n".utf8))

        XCTAssertEqual(lines, [#"{"id":1}"#, #"{"id":2}"#])
    }

    func testProcessTransportAppliesEnvironmentOverrides() async throws {
        let transport = ProcessLineTransport(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [],
            environmentOverrides: ["CODEX_HOME": "/tmp/plugin-codex-home"]
        )

        try await transport.start()
        var observedCodexHome: String?
        for await line in transport.lines {
            if line.hasPrefix("CODEX_HOME=") {
                observedCodexHome = String(line.dropFirst("CODEX_HOME=".count))
            }
        }

        XCTAssertEqual(observedCodexHome, "/tmp/plugin-codex-home")
    }
}
