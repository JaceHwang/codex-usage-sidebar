import Foundation
import XCTest
@testable import SidebarCore

final class AppServerClientTests: XCTestCase {
    func testInitializesThenReadsRateLimitsWithIncreasingIDs() async throws {
        let transport = InMemoryLineTransport()
        let client = AppServerClient(transportFactory: { transport })

        try await client.start()
        try await eventually {
            transport.sentLines.count == 1
        }

        let initialize = try XCTUnwrap(parse(transport.sentLines[0]))
        XCTAssertEqual(initialize["method"] as? String, "initialize")
        XCTAssertEqual((initialize["id"] as? NSNumber)?.intValue, 1)

        transport.emit(#"{"id":1,"result":{"serverInfo":{"name":"codex"}}}"#)
        try await eventually {
            transport.sentLines.count == 3
        }

        let initialized = try XCTUnwrap(parse(transport.sentLines[1]))
        let read = try XCTUnwrap(parse(transport.sentLines[2]))
        XCTAssertEqual(initialized["method"] as? String, "initialized")
        XCTAssertNil(initialized["id"])
        XCTAssertEqual(read["method"] as? String, "account/rateLimits/read")
        XCTAssertEqual((read["id"] as? NSNumber)?.intValue, 2)

        await client.stop()
    }

    func testResponseIDEmitsSnapshotAndMalformedJSONDoesNotStopReader() async throws {
        let transport = InMemoryLineTransport()
        let client = AppServerClient(transportFactory: { transport })
        try await completeHandshake(client: client, transport: transport)

        let snapshotTask = Task<AllowanceSnapshot?, Never> {
            for await snapshot in client.snapshots {
                return snapshot
            }
            return nil
        }

        transport.emit("{malformed")
        transport.emit(
            #"{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":24,"resetsAt":1785628824}}}}"#
        )

        let snapshotValue = await snapshotTask.value
        let snapshot = try XCTUnwrap(snapshotValue)
        XCTAssertEqual(snapshot.remainingPercent, 76)
        await client.stop()
    }

    func testRefreshCoalescesPendingReadAndResumesAfterResponse() async throws {
        let transport = InMemoryLineTransport()
        let client = AppServerClient(transportFactory: { transport })
        try await completeHandshake(client: client, transport: transport)

        try await client.refresh()
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(transport.sentLines.count, 3)

        let snapshotTask = Task<AllowanceSnapshot?, Never> {
            var iterator = client.snapshots.makeAsyncIterator()
            return await iterator.next()
        }
        transport.emit(
            #"{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":24,"resetsAt":1785628824}}}}"#
        )
        _ = await snapshotTask.value

        try await client.refresh()
        try await eventually {
            transport.sentLines.count == 4
        }
        let refresh = try XCTUnwrap(parse(transport.sentLines[3]))
        XCTAssertEqual(refresh["method"] as? String, "account/rateLimits/read")
        XCTAssertEqual((refresh["id"] as? NSNumber)?.intValue, 3)

        await client.stop()
    }

    func testUpdatedNotificationReplacesOlderSnapshot() async throws {
        let transport = InMemoryLineTransport()
        let client = AppServerClient(transportFactory: { transport })
        try await completeHandshake(client: client, transport: transport)

        let snapshotsTask = Task {
            var values: [AllowanceSnapshot] = []
            for await snapshot in client.snapshots {
                values.append(snapshot)
                if values.count == 2 {
                    return values
                }
            }
            return values
        }

        transport.emit(
            #"{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":24,"resetsAt":1785628824}}}}"#
        )
        transport.emit(
            #"{"method":"account/rateLimits/updated","params":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":31,"resetsAt":1785628824}}}}"#
        )

        let values = await snapshotsTask.value
        XCTAssertEqual(values.map(\.remainingPercent), [76, 69])
        await client.stop()
    }

    func testUpdatedNotificationPreservesBankDataAndRequestsFullRefresh() async throws {
        let transport = InMemoryLineTransport()
        let client = AppServerClient(transportFactory: { transport })
        try await completeHandshake(client: client, transport: transport)

        let snapshotsTask = Task {
            var values: [AllowanceSnapshot] = []
            for await snapshot in client.snapshots {
                values.append(snapshot)
                if values.count == 2 {
                    return values
                }
            }
            return values
        }

        transport.emit(
            """
            {"id":2,"result":{
              "rateLimits":{
                "limitId":"codex",
                "primary":{"usedPercent":24,"windowDurationMins":10080,"resetsAt":1785628824},
                "planType":"plus"
              },
              "rateLimitResetCredits":{"availableCount":2,"credits":[]}
            }}
            """
        )
        transport.emit(
            #"{"method":"account/rateLimits/updated","params":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":31,"resetsAt":1785628824}}}}"#
        )

        let values = await snapshotsTask.value
        XCTAssertEqual(values.map(\.remainingPercent), [76, 69])
        XCTAssertEqual(values.last?.windowDurationMins, 10080)
        XCTAssertEqual(values.last?.planType, "plus")
        XCTAssertEqual(values.last?.bank?.availableCount, 2)

        try await eventually {
            transport.sentLines.count == 4
        }
        let refresh = try XCTUnwrap(parse(transport.sentLines[3]))
        XCTAssertEqual(refresh["method"] as? String, "account/rateLimits/read")
        XCTAssertEqual((refresh["id"] as? NSNumber)?.intValue, 3)

        await client.stop()
    }

    func testNotificationDuringPendingReadNeverRevertsAndQueuesFollowUp() async throws {
        let transport = InMemoryLineTransport()
        let client = AppServerClient(transportFactory: { transport })
        try await completeHandshake(client: client, transport: transport)

        let snapshotsTask = Task {
            var values: [AllowanceSnapshot] = []
            for await snapshot in client.snapshots {
                values.append(snapshot)
                if values.count == 2 {
                    return values
                }
            }
            return values
        }

        transport.emit(
            #"{"method":"account/rateLimits/updated","params":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":31,"resetsAt":1785628824}}}}"#
        )
        transport.emit(
            """
            {"id":2,"result":{
              "rateLimits":{
                "limitId":"codex",
                "primary":{"usedPercent":24,"resetsAt":1785628824},
                "planType":"plus"
              },
              "rateLimitResetCredits":{"availableCount":1,"credits":[]}
            }}
            """
        )

        let values = await snapshotsTask.value
        XCTAssertEqual(values.map(\.remainingPercent), [69, 69])
        XCTAssertEqual(values.last?.planType, "plus")
        XCTAssertEqual(values.last?.bank?.availableCount, 1)
        try await eventually {
            transport.sentLines.count == 4
        }
        if transport.sentLines.count == 4 {
            let followUp = try XCTUnwrap(parse(transport.sentLines[3]))
            XCTAssertEqual(followUp["method"] as? String, "account/rateLimits/read")
            XCTAssertEqual((followUp["id"] as? NSNumber)?.intValue, 3)
        }

        await client.stop()
    }

    func testTransportExitSchedulesBoundedRestart() async throws {
        let first = InMemoryLineTransport()
        let second = InMemoryLineTransport()
        let transports = TransportQueue([first, second])
        let client = AppServerClient(
            transportFactory: { try transports.next() },
            restartDelaysNanoseconds: [0]
        )

        try await client.start()
        first.finish()

        try await eventually {
            await client.restartAttemptCount == 1 && second.started
        }
        let restartAttempts = await client.restartAttemptCount
        XCTAssertEqual(restartAttempts, 1)

        second.finish()
        try await Task.sleep(nanoseconds: 20_000_000)
        let attemptsAfterSecondExit = await client.restartAttemptCount
        XCTAssertEqual(attemptsAfterSecondExit, 1)
        await client.stop()
    }

    private func completeHandshake(
        client: AppServerClient,
        transport: InMemoryLineTransport
    ) async throws {
        try await client.start()
        try await eventually {
            transport.sentLines.count == 1
        }
        transport.emit(#"{"id":1,"result":{}}"#)
        try await eventually {
            transport.sentLines.count == 3
        }
    }

    private func parse(_ line: String) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
    }

    private func eventually(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping () async -> Bool
    ) async throws {
        let started = DispatchTime.now().uptimeNanoseconds
        while !(await condition()) {
            if DispatchTime.now().uptimeNanoseconds - started > timeoutNanoseconds {
                XCTFail("condition was not met before timeout")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

private final class InMemoryLineTransport: LineTransport, @unchecked Sendable {
    let lines: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation
    private let lock = NSLock()
    private var storage: [String] = []
    private var startStorage = false

    init() {
        let pair = AsyncStream<String>.makeStream()
        lines = pair.stream
        continuation = pair.continuation
    }

    var sentLines: [String] {
        lock.withLock { storage }
    }

    var started: Bool {
        lock.withLock { startStorage }
    }

    func start() async throws {
        lock.withLock {
            startStorage = true
        }
    }

    func send(line: String) async throws {
        lock.withLock {
            storage.append(line)
        }
    }

    func stop() async {
        continuation.finish()
    }

    func emit(_ line: String) {
        continuation.yield(line)
    }

    func finish() {
        continuation.finish()
    }
}

private final class TransportQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var transports: [InMemoryLineTransport]

    init(_ transports: [InMemoryLineTransport]) {
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
