import Foundation
import XCTest
@testable import CodexUsageSidebar
@testable import SidebarCore

@MainActor
final class RuntimeTokenUsageStateTests: XCTestCase {
    func testTokenStreamEventChangesDetailContentWithoutReplacingAllowance() async throws {
        let transport = CoordinatorLineTransport()
        let coordinator = RuntimeCoordinator(
            appServerClientFactory: { _ in
                AppServerClient(transportFactory: { transport })
            }
        )

        coordinator.replaceClient(using: hostInstallation())
        try await completeHandshake(on: transport)
        transport.emit(rateLimitResponse())
        try await eventually {
            coordinator.detailContent()?.remainingPercent == 68
        }
        let allowanceOnly = try XCTUnwrap(coordinator.detailContent())
        XCTAssertNil(allowanceOnly.tokenUsage)

        transport.emit(tokenUsageResponse())
        try await eventually {
            coordinator.detailContent()?.tokenUsage?.totalTokens == 456
        }
        let withUsage = try XCTUnwrap(coordinator.detailContent())
        XCTAssertEqual(withUsage.remainingPercent, 68)
        XCTAssertEqual(withUsage.tokenUsage?.totalTokens, 456)
        coordinator.stop()
    }

    func testReplacingAppServerClearsStaleTokenUsageFromCoordinatorDetail() async throws {
        let firstTransport = CoordinatorLineTransport()
        let secondTransport = CoordinatorLineTransport()
        let transports = CoordinatorTransportQueue([
            firstTransport,
            secondTransport
        ])
        let coordinator = RuntimeCoordinator(
            appServerClientFactory: { _ in
                AppServerClient(transportFactory: { try transports.next() })
            }
        )

        coordinator.replaceClient(using: hostInstallation())
        try await completeHandshake(on: firstTransport)
        firstTransport.emit(rateLimitResponse())
        firstTransport.emit(tokenUsageResponse())
        try await eventually {
            coordinator.detailContent()?.tokenUsage?.totalTokens == 456
        }

        coordinator.replaceClient(using: hostInstallation(buildIdentity: "second"))

        try await eventually {
            coordinator.detailContent()?.tokenUsage == nil
        }
        XCTAssertEqual(coordinator.detailContent()?.remainingPercent, 68)
        coordinator.stop()
    }

    func testUnsupportedTokenEventKeepsQuotaIndicatorDetailAvailable() async throws {
        let transport = CoordinatorLineTransport()
        let coordinator = RuntimeCoordinator(
            appServerClientFactory: { _ in
                AppServerClient(transportFactory: { transport })
            }
        )

        coordinator.replaceClient(using: hostInstallation())
        try await completeHandshake(on: transport)
        transport.emit(rateLimitResponse())
        transport.emit(#"{"id":3,"error":{"code":-32601,"message":"Method not found"}}"#)

        try await eventually {
            coordinator.detailContent()?.tokenUsage?.availability == .unsupported
        }
        let detail = try XCTUnwrap(coordinator.detailContent())
        XCTAssertEqual(detail.remainingPercent, 68)
        XCTAssertEqual(detail.tokenUsage?.availability, .unsupported)
        coordinator.stop()
    }

    func testUnavailableTokenEventAfterSuccessPreservesLastSuccessfulUsage() async throws {
        let transport = CoordinatorLineTransport()
        let coordinator = RuntimeCoordinator(
            appServerClientFactory: { _ in
                AppServerClient(transportFactory: { transport })
            }
        )

        coordinator.replaceClient(using: hostInstallation())
        try await completeHandshake(on: transport)
        transport.emit(rateLimitResponse())
        transport.emit(tokenUsageResponse())
        try await eventually {
            coordinator.detailContent()?.tokenUsage?.totalTokens == 456
        }

        coordinator.refreshNow(reason: .startup)
        try await eventually { transport.sentLines.count >= 6 }
        transport.emit(#"{"id":5,"error":{"code":-32000,"message":"temporary failure"}}"#)
        try await Task.sleep(nanoseconds: 50_000_000)

        let usage = try XCTUnwrap(coordinator.detailContent()?.tokenUsage)
        XCTAssertEqual(usage.availability, .available)
        XCTAssertEqual(usage.totalTokens, 456)
        coordinator.stop()
    }

    func testUnsupportedTokenEventAfterSuccessPreservesLastSuccessfulUsage() async throws {
        let transport = CoordinatorLineTransport()
        let coordinator = RuntimeCoordinator(
            appServerClientFactory: { _ in
                AppServerClient(transportFactory: { transport })
            }
        )

        coordinator.replaceClient(using: hostInstallation())
        try await completeHandshake(on: transport)
        transport.emit(rateLimitResponse())
        transport.emit(tokenUsageResponse())
        try await eventually {
            coordinator.detailContent()?.tokenUsage?.totalTokens == 456
        }

        coordinator.refreshNow(reason: .startup)
        try await eventually { transport.sentLines.count >= 6 }
        transport.emit(#"{"id":5,"error":{"code":-32601,"message":"Method not found"}}"#)
        try await Task.sleep(nanoseconds: 50_000_000)

        let usage = try XCTUnwrap(coordinator.detailContent()?.tokenUsage)
        XCTAssertEqual(usage.availability, .available)
        XCTAssertEqual(usage.totalTokens, 456)
        coordinator.stop()
    }

    func testAccountReadResponseFlowsIntoDetailFooter() async throws {
        let transport = CoordinatorLineTransport()
        let coordinator = RuntimeCoordinator(
            appServerClientFactory: { _ in
                AppServerClient(transportFactory: { transport })
            }
        )

        coordinator.replaceClient(using: hostInstallation())
        try await completeHandshake(on: transport)
        transport.emit(rateLimitResponse())
        try await eventually {
            coordinator.detailContent() != nil
        }

        try await eventually { transport.sentLines.count >= 5 }
        transport.emit(
            #"{"id":4,"result":{"account":{"email":"jace@example.com"}}}"#
        )
        try await eventually {
            coordinator.detailContent()?.footerName == "jace@example.com"
        }
        let detail = try XCTUnwrap(coordinator.detailContent())
        XCTAssertEqual(detail.footerName, "jace@example.com")
        coordinator.stop()
    }

    private func hostInstallation(
        buildIdentity: String = "first"
    ) -> HostInstallation {
        HostInstallation(
            appServerExecutableURL: URL(fileURLWithPath: "/usr/bin/true"),
            bundleURL: nil,
            bundleVersion: nil,
            buildIdentity: buildIdentity,
            source: .path,
            processIdentifier: nil
        )
    }

    private func completeHandshake(
        on transport: CoordinatorLineTransport
    ) async throws {
        try await eventually { transport.sentLines.count == 1 }
        transport.emit(#"{"id":1,"result":{}}"#)
        try await eventually { transport.sentLines.count >= 4 }
    }

    private func rateLimitResponse() -> String {
        #"{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":32,"windowDurationMins":10080,"resetsAt":1787225504}}}}"#
    }

    private func tokenUsageResponse() -> String {
        #"{"id":3,"result":{"dailyUsageBuckets":[{"startDate":"2026-08-14","tokens":456}]}}"#
    }

    private func eventually(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let started = DispatchTime.now().uptimeNanoseconds
        while !condition() {
            if DispatchTime.now().uptimeNanoseconds - started > timeoutNanoseconds {
                XCTFail("condition was not met before timeout")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

private final class CoordinatorLineTransport: LineTransport, @unchecked Sendable {
    let lines: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation
    private let lock = NSLock()
    private var sentLineStorage: [String] = []

    init() {
        let pair = AsyncStream<String>.makeStream()
        lines = pair.stream
        continuation = pair.continuation
    }

    var sentLines: [String] {
        lock.withLock { sentLineStorage }
    }

    func start() async throws {}

    func send(line: String) async throws {
        lock.withLock {
            sentLineStorage.append(line)
        }
    }

    func stop() async {
        continuation.finish()
    }

    func emit(_ line: String) {
        continuation.yield(line)
    }
}

private final class CoordinatorTransportQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var transports: [CoordinatorLineTransport]

    init(_ transports: [CoordinatorLineTransport]) {
        self.transports = transports
    }

    func next() throws -> any LineTransport {
        try lock.withLock {
            guard !transports.isEmpty else {
                throw AppServerClientError.transportUnavailable
            }
            return transports.removeFirst()
        }
    }
}
