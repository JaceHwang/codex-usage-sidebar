import AppKit
import Foundation
import SidebarCore

@MainActor
final class RuntimeCoordinator: NSObject {
    private let overlay = OverlayPanel()
    private let accessibility = AccessibilityLocator()
    private let sidebarVisibility = SidebarVisibilityLocator()
    private let formatter = ResetFormatter()
    private let detailFormatter = QuotaDetailFormatter()
    private let policy = RefreshPolicy()
    private let themeProvider = CodexThemeProvider(
        configurationURL: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/config.toml")
    )
    private let sidebarState = SidebarStateTracker()
    private var sidebarProbeGate = SidebarProbeGate()

    private var host: HostInstallation?
    private var client: AppServerClient?
    private var clientStartedAt: Date?
    private var snapshot: AllowanceSnapshot?
    private var snapshotTask: Task<Void, Never>?
    private var timer: Timer?
    private var nextPeriodicRefresh = Date.distantPast
    private var nextResetRefresh: Date?
    private var lastDiagnosticState: String?

    func start() {
        sidebarState.start { [weak self] in
            guard let self else {
                return
            }
            self.sidebarProbeGate.observeHint(at: Date())
            self.reconcileOverlay()
        }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(sidebarStateSynchronized(_:)),
            name: .codexUsageSidebarStateSynchronized,
            object: nil
        )
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(applicationLifecycleChanged(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(applicationLifecycleChanged(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        reconcileHost()
        refreshNow(reason: .startup)
        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        reconcileOverlay()
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timer?.invalidate()
        timer = nil
        snapshotTask?.cancel()
        snapshotTask = nil
        if let client {
            Task {
                await client.stop()
            }
        }
        client = nil
        clientStartedAt = nil
        sidebarState.stop()
        overlay.hide()
    }

    func refreshNow(reason: RefreshReason) {
        let foreground = isCodexForeground
        nextPeriodicRefresh = Date().addingTimeInterval(
            policy.intervalSeconds(isHostForeground: foreground)
        )
        guard
            policy.shouldRefreshImmediately(for: reason),
            let client
        else {
            return
        }
        Task {
            try? await client.refresh()
        }
    }

    func reconcileOverlay() {
        guard isCodexForeground else {
            recordDiagnosticState("hidden:not-foreground")
            overlay.hide()
            return
        }
        guard let host, let processIdentifier = host.processIdentifier else {
            recordDiagnosticState("hidden:no-running-host")
            overlay.hide()
            return
        }
        guard let snapshot else {
            recordDiagnosticState("hidden:no-snapshot")
            overlay.hide()
            return
        }

        let freshness = policy.freshness(
            receivedAt: snapshot.receivedAt,
            now: Date()
        )
        guard freshness != .hidden else {
            recordDiagnosticState("hidden:stale")
            overlay.hide()
            return
        }
        guard let windowFrame = accessibility.hostWindowFrame(
            for: processIdentifier
        ) else {
            recordDiagnosticState("hidden:no-window")
            overlay.hide()
            return
        }
        let hostIdentity = "\(processIdentifier):\(host.buildIdentity)"
        sidebarState.observeHost(
            identity: hostIdentity,
            processIdentifier: processIdentifier,
            windowFrame: windowFrame
        )
        let chromeProbe: SidebarChromeProbe
        if sidebarProbeGate.shouldProbe(at: Date()) {
            chromeProbe = sidebarVisibility.probe(
                for: processIdentifier,
                windowFrame: windowFrame
            )
        } else {
            chromeProbe = .skipped
        }
        switch OverlayPresentationPolicy.decision(for: chromeProbe) {
        case .preserve:
            break
        case let .show(actualPlacement):
            sidebarState.observeActualPlacement(actualPlacement)
        case .hide:
            recordDiagnosticState("hidden:non-main-surface")
            overlay.hide()
            return
        }
        let placement = sidebarState.placement
        let indicatorFrame: CGRect
        switch placement {
        case .sidebar:
            guard let rowFrame = accessibility.profileRow(
                for: processIdentifier
            ) else {
                recordDiagnosticState("hidden:no-anchor")
                overlay.hide()
                return
            }
            indicatorFrame = OverlayLayout.sidebarIndicatorFrame(in: rowFrame)
        case .titlebar:
            indicatorFrame = OverlayLayout.titlebarIndicatorFrame(
                in: windowFrame,
                rightControlsLeadingEdge: sidebarVisibility
                    .rightTitlebarControlsLeadingEdge
            )
        }

        let maximumLabelWidth = min(148, max(70, indicatorFrame.width))
        let label = formatter.label(
            snapshot: snapshot,
            now: Date(),
            locale: .autoupdatingCurrent,
            timeZone: .autoupdatingCurrent,
            maxWidth: maximumLabelWidth
        )
        overlay.show(
            snapshot: snapshot,
            label: label,
            indicatorFrame: indicatorFrame,
            placement: placement,
            theme: currentTheme,
            detail: detailFormatter.content(
                snapshot: snapshot,
                now: Date(),
                locale: .autoupdatingCurrent,
                timeZone: .autoupdatingCurrent
            ),
            dimmed: freshness == .dimmed
        )
        recordDiagnosticState("shown placement=\(placement.rawValue)")
    }

    func diagnosticSummary() -> String {
        guard let host = HostDiscovery.current() else {
            return "host=missing app_server=missing accessibility=unknown anchor=unavailable"
        }
        let trusted = accessibility.isTrusted(prompt: false)
        let anchorFound: Bool
        var reportedPlacement = sidebarState.placement
        var sidebarDiagnostic = "sidebar_probe=unknown"
        if trusted, let pid = host.processIdentifier {
            anchorFound = accessibility.profileRow(for: pid) != nil
            if let windowFrame = accessibility.hostWindowFrame(for: pid) {
                sidebarDiagnostic = sidebarVisibility.diagnosticDetail(
                    for: pid,
                    windowFrame: windowFrame
                )
                let observedPlacement = sidebarVisibility.placement(
                    for: pid,
                    windowFrame: windowFrame
                )
                if observedPlacement != nil {
                    reportedPlacement = .titlebar
                }
            }
        } else {
            anchorFound = false
        }
        return [
            "host=found",
            "app_server=found",
            "accessibility=\(trusted ? "granted" : "required")",
            "anchor=\(anchorFound ? "found" : "unavailable")",
            "placement=\(reportedPlacement.rawValue)",
            "source=\(host.source.rawValue)",
            sidebarDiagnostic,
            host.processIdentifier.map {
                accessibility.diagnosticDetail(for: $0)
            } ?? "ax=no-running-host"
        ].joined(separator: " ")
    }

    func syncActualSidebarStateOnce() -> String {
        guard
            let host = HostDiscovery.current(),
            let processIdentifier = host.processIdentifier,
            let windowFrame = accessibility.hostWindowFrame(
                for: processIdentifier
            )
        else {
            return "sidebar_sync=unavailable"
        }

        sidebarState.observeHost(
            identity: "\(processIdentifier):\(host.buildIdentity)",
            processIdentifier: processIdentifier,
            windowFrame: windowFrame
        )
        guard let placement = sidebarVisibility.placement(
            for: processIdentifier,
            windowFrame: windowFrame
        ) else {
            return "sidebar_sync=unavailable"
        }
        sidebarState.observeActualPlacement(placement)
        DistributedNotificationCenter.default().postNotificationName(
            .codexUsageSidebarStateSynchronized,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return "sidebar_sync=\(sidebarState.placement.rawValue)"
    }

    private var isCodexForeground: Bool {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier ==
            "com.openai.codex"
        {
            return true
        }
        guard
            let processIdentifier = host?.processIdentifier,
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }
        let windows = windowInfo.compactMap { item -> WindowOwner? in
            guard
                let pid = (
                    item[kCGWindowOwnerPID as String] as? NSNumber
                )?.int32Value,
                let layer = (
                    item[kCGWindowLayer as String] as? NSNumber
                )?.intValue,
                let bounds = item[kCGWindowBounds as String]
                    as? [String: Any],
                let frame = CGRect(
                    dictionaryRepresentation: bounds as CFDictionary
                )
            else {
                return nil
            }
            return WindowOwner(
                processIdentifier: pid,
                layer: layer,
                frame: frame
            )
        }
        return ForegroundWindowDetector.isHostFrontmost(
            hostProcessIdentifier: processIdentifier,
            orderedWindows: windows
        )
    }

    private var currentTheme: CodexInterfaceTheme {
        let systemIsDark = NSApplication.shared.effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua
        return themeProvider.currentTheme(systemIsDark: systemIsDark)
    }

    private func tick() {
        reconcileHost()
        let now = Date()
        if
            let clientStartedAt,
            policy.shouldRecoverStream(
                lastSnapshotAt: snapshot?.receivedAt,
                clientStartedAt: clientStartedAt,
                now: now
            )
        {
            replaceClient(using: host)
            nextPeriodicRefresh = .distantPast
        }
        if now >= nextPeriodicRefresh {
            refreshNow(reason: .timer)
            if let client {
                Task {
                    try? await client.refresh()
                }
            }
        }
        if let nextResetRefresh, now >= nextResetRefresh {
            self.nextResetRefresh = nil
            refreshNow(reason: .reset)
        }
        reconcileOverlay()
    }

    private func reconcileHost() {
        let discovered = HostDiscovery.current()
        let previousHostIdentity = host.map {
            "\($0.processIdentifier ?? -1):\($0.buildIdentity)"
        }
        let discoveredHostIdentity = discovered.map {
            "\($0.processIdentifier ?? -1):\($0.buildIdentity)"
        }
        let actions = policy.actionsForHostTransition(
            from: host?.buildIdentity,
            to: discovered?.buildIdentity
        )
        if actions.invalidateAnchor {
            accessibility.invalidateCachedAnchor()
        }
        if previousHostIdentity != discoveredHostIdentity {
            sidebarVisibility.invalidate()
        }

        let executableChanged = host?.appServerExecutableURL !=
            discovered?.appServerExecutableURL
        let needsClient = client == nil && discovered != nil
        host = discovered
        if
            let discovered,
            let processIdentifier = discovered.processIdentifier
        {
            sidebarState.observeHost(
                identity: "\(processIdentifier):\(discovered.buildIdentity)",
                processIdentifier: processIdentifier,
                windowFrame: accessibility.hostWindowFrame(
                    for: processIdentifier
                )
            )
        }
        if actions.restartClient || executableChanged || needsClient {
            replaceClient(using: discovered)
        }
    }

    private func replaceClient(using host: HostInstallation?) {
        snapshotTask?.cancel()
        snapshotTask = nil
        if let oldClient = client {
            Task {
                await oldClient.stop()
            }
        }
        client = nil
        clientStartedAt = nil

        guard let host else {
            overlay.hide()
            return
        }

        let newClient = AppServerClient(
            executableURL: host.appServerExecutableURL
        )
        client = newClient
        clientStartedAt = Date()
        snapshotTask = Task { [weak self] in
            for await value in newClient.snapshots {
                guard !Task.isCancelled else {
                    break
                }
                self?.received(value)
            }
        }
        Task {
            try? await newClient.start()
        }
    }

    private func received(_ newSnapshot: AllowanceSnapshot) {
        snapshot = newSnapshot
        nextResetRefresh = policy.nextResetRefresh(
            resetsAt: newSnapshot.resetsAt
        )
        refreshNow(reason: .notification)
        reconcileOverlay()
    }

    private func recordDiagnosticState(_ state: String) {
        guard
            ProcessInfo.processInfo.environment["CUS_DIAGNOSTIC_LOG"] == "1",
            state != lastDiagnosticState
        else {
            return
        }
        lastDiagnosticState = state
        print("runtime=\(state)")
        fflush(stdout)
    }

    @objc
    private func sidebarStateSynchronized(_ notification: Notification) {
        guard sidebarState.reloadPersistedPlacement() else {
            return
        }
        sidebarProbeGate.observeHint(at: Date())
        reconcileOverlay()
    }

    @objc
    private func applicationActivated(_ notification: Notification) {
        guard
            let application = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication,
            application.bundleIdentifier == "com.openai.codex"
        else {
            overlay.hide()
            return
        }
        reconcileHost()
        refreshNow(reason: .focus)
        reconcileOverlay()
    }

    @objc
    private func applicationLifecycleChanged(_ notification: Notification) {
        guard
            let application = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication,
            application.bundleIdentifier == "com.openai.codex"
        else {
            return
        }
        reconcileHost()
        reconcileOverlay()
    }
}
