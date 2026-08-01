import Foundation

public enum AppServerClientError: Error, Equatable, Sendable {
    case transportUnavailable
    case notInitialized
    case remoteError
}

public actor AppServerClient {
    public nonisolated let snapshots: AsyncStream<AllowanceSnapshot>
    public private(set) var restartAttemptCount = 0

    private enum PendingMethod {
        case initialize
        case readRateLimits
    }

    private let snapshotContinuation: AsyncStream<AllowanceSnapshot>.Continuation
    private let transportFactory: @Sendable () throws -> any LineTransport
    private let restartDelaysNanoseconds: [UInt64]
    private var transport: (any LineTransport)?
    private var readerTask: Task<Void, Never>?
    private var sequencer = JSONRPCSequencer()
    private var pending: [Int: PendingMethod] = [:]
    private var initialized = false
    private var stopping = false
    private var generation = 0
    private var restartIndex = 0
    private var lastSnapshot: AllowanceSnapshot?
    private var rateLimitReadNeededAfterPending = false

    public init(
        transportFactory: @escaping @Sendable () throws -> any LineTransport,
        restartDelaysNanoseconds: [UInt64] = [
            500_000_000,
            2_000_000_000,
            5_000_000_000
        ]
    ) {
        self.transportFactory = transportFactory
        self.restartDelaysNanoseconds = restartDelaysNanoseconds
        let pair = AsyncStream<AllowanceSnapshot>.makeStream(
            bufferingPolicy: .bufferingNewest(4)
        )
        snapshots = pair.stream
        snapshotContinuation = pair.continuation
    }

    public init(
        executableURL: URL,
        restartDelaysNanoseconds: [UInt64] = [
            500_000_000,
            2_000_000_000,
            5_000_000_000
        ]
    ) {
        self.init(
            transportFactory: {
                ProcessLineTransport(executableURL: executableURL)
            },
            restartDelaysNanoseconds: restartDelaysNanoseconds
        )
    }

    public func start() async throws {
        guard transport == nil else {
            return
        }
        stopping = false
        restartIndex = 0
        restartAttemptCount = 0
        try await startSession()
    }

    public func refresh() async throws {
        guard initialized else {
            throw AppServerClientError.notInitialized
        }
        guard !hasPendingRateLimitRead else {
            return
        }
        _ = try await sendRequest(method: "account/rateLimits/read")
    }

    public func stop() async {
        stopping = true
        readerTask?.cancel()
        readerTask = nil
        let activeTransport = transport
        transport = nil
        initialized = false
        pending.removeAll()
        lastSnapshot = nil
        rateLimitReadNeededAfterPending = false
        await activeTransport?.stop()
        snapshotContinuation.finish()
    }

    private func startSession() async throws {
        let newTransport = try transportFactory()
        generation += 1
        let sessionGeneration = generation
        transport = newTransport
        initialized = false
        pending.removeAll()
        lastSnapshot = nil
        rateLimitReadNeededAfterPending = false

        do {
            try await newTransport.start()
        } catch {
            transport = nil
            throw error
        }

        readerTask = Task { [weak self] in
            for await line in newTransport.lines {
                await self?.handle(line: line, generation: sessionGeneration)
            }
            await self?.transportFinished(generation: sessionGeneration)
        }

        let parameters: [String: Any] = [
            "clientInfo": [
                "name": "codex-usage-sidebar",
                "title": "Codex Usage Sidebar",
                "version": "1.0.0"
            ],
            "capabilities": [
                "experimentalApi": true,
                "requestAttestation": false
            ]
        ]
        _ = try await sendRequest(method: "initialize", params: parameters)
    }

    private func sendRequest(
        method: String,
        params: [String: Any]? = nil
    ) async throws -> Int {
        guard let transport else {
            throw AppServerClientError.transportUnavailable
        }
        let id = sequencer.nextRequestID()
        var object: [String: Any] = [
            "method": method,
            "id": id
        ]
        if let params {
            object["params"] = params
        }
        let line = try encode(object)
        pending[id] = method == "initialize" ? .initialize : .readRateLimits
        do {
            try await transport.send(line: line)
        } catch {
            pending.removeValue(forKey: id)
            throw error
        }
        return id
    }

    private func sendNotification(method: String) async throws {
        guard let transport else {
            throw AppServerClientError.transportUnavailable
        }
        try await transport.send(line: encode(["method": method]))
    }

    private func handle(line: String, generation: Int) async {
        guard generation == self.generation else {
            return
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: Data(line.utf8))
                as? [String: Any]
        else {
            return
        }

        if object["method"] as? String == "account/rateLimits/updated" {
            if let snapshot = try? RateLimitDecoder.decodeNotification(Data(line.utf8)) {
                let enriched = snapshot.mergingSupplementary(from: lastSnapshot)
                lastSnapshot = enriched
                snapshotContinuation.yield(enriched)
            }
            if initialized {
                if hasPendingRateLimitRead {
                    rateLimitReadNeededAfterPending = true
                } else {
                    do {
                        _ = try await sendRequest(method: "account/rateLimits/read")
                    } catch {
                        await restartAfterFailure()
                    }
                }
            }
            return
        }

        guard
            let number = object["id"] as? NSNumber,
            let method = pending.removeValue(forKey: number.intValue)
        else {
            return
        }
        guard object["error"] == nil else {
            if case .readRateLimits = method {
                await sendDeferredRateLimitReadIfNeeded()
            }
            return
        }

        switch method {
        case .initialize:
            initialized = true
            do {
                try await sendNotification(method: "initialized")
                _ = try await sendRequest(method: "account/rateLimits/read")
            } catch {
                await restartAfterFailure()
            }
        case .readRateLimits:
            if let snapshot = try? RateLimitDecoder.decodeResponse(Data(line.utf8)) {
                let value = rateLimitReadNeededAfterPending
                    ? (lastSnapshot?.mergingSupplementary(from: snapshot) ?? snapshot)
                    : snapshot
                lastSnapshot = value
                snapshotContinuation.yield(value)
            }
            await sendDeferredRateLimitReadIfNeeded()
        }
    }

    private func sendDeferredRateLimitReadIfNeeded() async {
        guard initialized, rateLimitReadNeededAfterPending else {
            return
        }
        rateLimitReadNeededAfterPending = false
        do {
            _ = try await sendRequest(method: "account/rateLimits/read")
        } catch {
            await restartAfterFailure()
        }
    }

    private var hasPendingRateLimitRead: Bool {
        pending.values.contains { method in
            if case .readRateLimits = method {
                return true
            }
            return false
        }
    }

    private func transportFinished(generation: Int) async {
        guard generation == self.generation, !stopping else {
            return
        }
        transport = nil
        readerTask = nil
        initialized = false
        pending.removeAll()
        rateLimitReadNeededAfterPending = false
        scheduleRestart()
    }

    private func restartAfterFailure() async {
        let activeTransport = transport
        transport = nil
        initialized = false
        pending.removeAll()
        rateLimitReadNeededAfterPending = false
        await activeTransport?.stop()
        scheduleRestart()
    }

    private func scheduleRestart() {
        guard !stopping, restartIndex < restartDelaysNanoseconds.count else {
            return
        }
        let delay = restartDelaysNanoseconds[restartIndex]
        restartIndex += 1
        restartAttemptCount += 1
        let expectedGeneration = generation

        Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            await self?.performRestart(expectedGeneration: expectedGeneration)
        }
    }

    private func performRestart(expectedGeneration: Int) async {
        guard
            !stopping,
            transport == nil,
            generation == expectedGeneration
        else {
            return
        }
        do {
            try await startSession()
        } catch {
            scheduleRestart()
        }
    }

    private func encode(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let line = String(data: data, encoding: .utf8) else {
            throw LineTransportError.invalidLine
        }
        return line
    }
}
