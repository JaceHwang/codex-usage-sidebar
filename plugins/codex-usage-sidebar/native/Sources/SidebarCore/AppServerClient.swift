import Foundation

public enum AppServerClientError: Error, Equatable, Sendable {
    case transportUnavailable
    case notInitialized
    case remoteError
}

public actor AppServerClient {
    public nonisolated let snapshots: AsyncStream<AllowanceSnapshot>
    public nonisolated let tokenUsages: AsyncStream<TokenUsageSnapshot>
    public nonisolated let accounts: AsyncStream<AccountIdentity>
    public private(set) var restartAttemptCount = 0

    private enum PendingMethod {
        case initialize
        case readRateLimits
        case readTokenUsage
        case readAccount
    }

    private let snapshotContinuation: AsyncStream<AllowanceSnapshot>.Continuation
    private let tokenUsageContinuation: AsyncStream<TokenUsageSnapshot>.Continuation
    private let accountContinuation: AsyncStream<AccountIdentity>.Continuation
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
    private var tokenUsageReadNeededAfterPending = false
    private var accountReadNeededAfterInitialization = false

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
        let tokenUsagePair = AsyncStream<TokenUsageSnapshot>.makeStream(
            bufferingPolicy: .bufferingNewest(4)
        )
        tokenUsages = tokenUsagePair.stream
        tokenUsageContinuation = tokenUsagePair.continuation
        let accountPair = AsyncStream<AccountIdentity>.makeStream(
            bufferingPolicy: .bufferingNewest(2)
        )
        accounts = accountPair.stream
        accountContinuation = accountPair.continuation
    }

    public init(
        executableURL: URL,
        environmentOverrides: [String: String] = [:],
        restartDelaysNanoseconds: [UInt64] = [
            500_000_000,
            2_000_000_000,
            5_000_000_000
        ]
    ) {
        self.init(
            transportFactory: {
                ProcessLineTransport(
                    executableURL: executableURL,
                    environmentOverrides: environmentOverrides
                )
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
        if !hasPendingRateLimitRead {
            _ = try await sendRequest(method: "account/rateLimits/read")
        }
        if hasPendingTokenUsageRead {
            tokenUsageReadNeededAfterPending = true
        } else {
            _ = try await sendRequest(method: "account/usage/read")
        }
    }

    public func readAccount() async throws {
        guard transport != nil else {
            throw AppServerClientError.notInitialized
        }
        guard initialized else {
            accountReadNeededAfterInitialization = true
            return
        }
        _ = try await sendRequest(method: "account/read", params: [:])
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
        tokenUsageReadNeededAfterPending = false
        accountReadNeededAfterInitialization = false
        await activeTransport?.stop()
        snapshotContinuation.finish()
        tokenUsageContinuation.finish()
        accountContinuation.finish()
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
        tokenUsageReadNeededAfterPending = false

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
        switch method {
        case "initialize":
            pending[id] = .initialize
        case "account/rateLimits/read":
            pending[id] = .readRateLimits
        case "account/usage/read":
            pending[id] = .readTokenUsage
        case "account/read":
            pending[id] = .readAccount
        default:
            throw AppServerClientError.remoteError
        }
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
            switch method {
            case .readRateLimits:
                await sendDeferredRateLimitReadIfNeeded()
            case .readTokenUsage:
                yieldUnavailableTokenUsage(from: Data(line.utf8))
                await sendDeferredTokenUsageReadIfNeeded()
            case .readAccount:
                break
            case .initialize:
                break
            }
            return
        }

        switch method {
        case .initialize:
            initialized = true
            do {
                try await sendNotification(method: "initialized")
                _ = try await sendRequest(method: "account/rateLimits/read")
                _ = try await sendRequest(method: "account/usage/read")
                await sendDeferredAccountReadIfNeeded()
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
        case .readTokenUsage:
            do {
                tokenUsageContinuation.yield(
                    try TokenUsageDecoder.decodeResponse(Data(line.utf8))
                )
            } catch {
                yieldUnavailableTokenUsage(from: Data(line.utf8))
            }
            await sendDeferredTokenUsageReadIfNeeded()
        case .readAccount:
            if let identity = try? AccountIdentityDecoder.decodeResponse(
                Data(line.utf8)
            ) {
                accountContinuation.yield(identity)
            }
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

    private func sendDeferredTokenUsageReadIfNeeded() async {
        guard initialized, tokenUsageReadNeededAfterPending else {
            return
        }
        tokenUsageReadNeededAfterPending = false
        do {
            _ = try await sendRequest(method: "account/usage/read")
        } catch {
            await restartAfterFailure()
        }
    }

    private func sendDeferredAccountReadIfNeeded() async {
        guard initialized, accountReadNeededAfterInitialization else {
            return
        }
        accountReadNeededAfterInitialization = false
        do {
            _ = try await sendRequest(method: "account/read", params: [:])
        } catch {
            await restartAfterFailure()
        }
    }

    private func yieldUnavailableTokenUsage(from data: Data) {
        let availability: TokenUsageAvailability
        do {
            _ = try TokenUsageDecoder.decodeResponse(data)
            availability = .unavailable
        } catch TokenUsageDecodingError.unsupported {
            availability = .unsupported
        } catch {
            availability = .unavailable
        }
        tokenUsageContinuation.yield(
            TokenUsageSnapshot(
                receivedAt: Date(),
                dailyBuckets: [],
                summary: nil,
                availability: availability
            )
        )
    }

    private var hasPendingRateLimitRead: Bool {
        pending.values.contains { method in
            if case .readRateLimits = method {
                return true
            }
            return false
        }
    }

    private var hasPendingTokenUsageRead: Bool {
        pending.values.contains { method in
            if case .readTokenUsage = method {
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
        tokenUsageReadNeededAfterPending = false
        scheduleRestart()
    }

    private func restartAfterFailure() async {
        let activeTransport = transport
        transport = nil
        initialized = false
        pending.removeAll()
        rateLimitReadNeededAfterPending = false
        tokenUsageReadNeededAfterPending = false
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
