import AppKit
import Foundation
import SidebarCore

@MainActor
final class RuntimeCoordinator: NSObject {
    private let overlay = OverlayPanel()
    private let accessibility = AccessibilityLocator()
    private let contentHeader = ContentHeaderLocator()
    private let formatter = ResetFormatter()
    private let detailFormatter = QuotaDetailFormatter()
    private let policy = RefreshPolicy()
    private let languageProvider = CodexEffectiveLanguageProvider()
    private let themeProvider = CodexThemeProvider(
        configurationURL: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/config.toml")
    )
    private var host: HostInstallation?
    private var client: AppServerClient?
    private var clientStartedAt: Date?
    private var snapshot: AllowanceSnapshot?
    private var snapshotTask: Task<Void, Never>?
    private var timer: Timer?
    private var layoutTimer: Timer?
    private var nextPeriodicRefresh = Date.distantPast
    private var nextResetRefresh: Date?
    private var lastDiagnosticState: String?
    private var languageState = RuntimeLanguageState()
    private let appServerEnvironmentOverrides: [String: String]
    private let runtimeStateURL: URL?

    init(
        appServerEnvironmentOverrides: [String: String] = [:],
        runtimeStateURL: URL? = nil
    ) {
        self.appServerEnvironmentOverrides = appServerEnvironmentOverrides
        self.runtimeStateURL = runtimeStateURL
        super.init()
    }

    func start() {
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

        reconcileLanguage()
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
        let layoutTimer = Timer(timeInterval: 0.1, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated {
                self?.trackOverlayPosition()
            }
        }
        RunLoop.main.add(layoutTimer, forMode: .common)
        self.layoutTimer = layoutTimer
        reconcileOverlay()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timer?.invalidate()
        timer = nil
        layoutTimer?.invalidate()
        layoutTimer = nil
        snapshotTask?.cancel()
        snapshotTask = nil
        if let client {
            Task {
                await client.stop()
            }
        }
        client = nil
        clientStartedAt = nil
        hideOverlay()
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
            hideOverlay()
            return
        }
        guard let host, let processIdentifier = host.processIdentifier else {
            recordDiagnosticState("hidden:no-running-host")
            hideOverlay()
            return
        }
        guard let snapshot else {
            recordDiagnosticState("hidden:no-snapshot")
            hideOverlay()
            return
        }

        let freshness = policy.freshness(
            receivedAt: snapshot.receivedAt,
            now: Date()
        )
        guard freshness != .hidden else {
            recordDiagnosticState("hidden:stale")
            hideOverlay()
            return
        }
        guard let windowFrame = accessibility.hostWindowFrame(
            for: processIdentifier
        ) else {
            recordDiagnosticState("hidden:no-window")
            hideOverlay()
            return
        }
        let anchor = contentHeader.resolve(
            for: processIdentifier,
            windowFrame: windowFrame
        )
        guard !contentHeader.isSettingsPage else {
            recordDiagnosticState("hidden:settings")
            hideOverlay()
            return
        }
        let indicatorFrame = OverlayLayout.indicatorFrame(
            in: windowFrame,
            contentTrailingEdge: anchor.trailingEdge
        )
        let maximumLabelWidth = min(
            OverlayLayout.indicatorWidth,
            max(70, indicatorFrame.width)
        )
        let label = formatter.label(
            snapshot: snapshot,
            now: Date(),
            language: languageState.language,
            timeZone: .autoupdatingCurrent,
            maxWidth: maximumLabelWidth
        )
        let detail = detailFormatter.content(
            snapshot: snapshot,
            now: Date(),
            language: languageState.language,
            timeZone: .autoupdatingCurrent
        )
        overlay.show(
            snapshot: snapshot,
            label: label,
            indicatorFrame: indicatorFrame,
            theme: currentTheme,
            detail: detail,
            dimmed: freshness == .dimmed
        )

        recordDiagnosticState(
            "shown placement=content-header anchor=\(anchor.source.rawValue) " +
                "indicator=\(Int(indicatorFrame.minX))," +
                "\(Int(indicatorFrame.minY))," +
                "\(Int(indicatorFrame.width))," +
                "\(Int(indicatorFrame.height)) " +
                contentHeader.latestDiagnosticDetail
        )
    }

    func diagnosticSummary() -> String {
        reconcileLanguage()
        let languageDescription = diagnosticLanguageDescription
        guard let host = HostDiscovery.current() else {
            return "host=missing app_server=missing accessibility=unknown " +
                "anchor=unavailable \(languageDescription)"
        }
        let trusted = accessibility.isTrusted(prompt: false)
        var anchor = ContentHeaderAnchor(
            trailingEdge: nil,
            source: .fallback
        )
        if
            trusted,
            let pid = host.processIdentifier,
            let windowFrame = accessibility.hostWindowFrame(for: pid)
        {
            anchor = contentHeader.resolve(
                for: pid,
                windowFrame: windowFrame
            )
        }
        return [
            "host=found",
            "app_server=found",
            "accessibility=\(trusted ? "granted" : "required")",
            "anchor=\(anchor.source.rawValue)",
            "placement=content-header",
            "source=\(host.source.rawValue)",
            languageDescription,
            contentHeader.latestDiagnosticDetail
        ].joined(separator: " ")
    }

    private func trackOverlayPosition() {
        guard
            isCodexForeground,
            let processIdentifier = host?.processIdentifier,
            let windowFrame = accessibility.hostWindowFrame(
                for: processIdentifier
            )
        else {
            return
        }
        let anchor = contentHeader.resolve(
            for: processIdentifier,
            windowFrame: windowFrame
        )
        guard !contentHeader.isSettingsPage else {
            hideOverlay()
            return
        }
        guard anchor.trailingEdge != nil else {
            return
        }
        overlay.reposition(
            to: OverlayLayout.indicatorFrame(
                in: windowFrame,
                contentTrailingEdge: anchor.trailingEdge
            )
        )
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
        reconcileLanguage()
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
        let actions = policy.actionsForHostTransition(
            from: host?.buildIdentity,
            to: discovered?.buildIdentity
        )

        let executableChanged = host?.appServerExecutableURL !=
            discovered?.appServerExecutableURL
        let needsClient = client == nil && discovered != nil
        host = discovered
        if actions.restartClient || executableChanged || needsClient {
            replaceClient(using: discovered)
        }
    }

    private func reconcileLanguage() {
        _ = languageState.apply(languageProvider.currentLanguage())
    }

    private var diagnosticLanguageDescription: String {
        let source = languageState.source?.rawValue ?? "fallback"
        return "language=\(languageState.language.rawValue) " +
            "language_source=\(source)"
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
            hideOverlay()
            return
        }

        let newClient = AppServerClient(
            executableURL: host.appServerExecutableURL,
            environmentOverrides: appServerEnvironmentOverrides
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
        let sanitizedState = "\(state) \(diagnosticLanguageDescription)"
        guard sanitizedState != lastDiagnosticState else {
            return
        }
        lastDiagnosticState = sanitizedState
        writeRuntimeState(sanitizedState)
        if ProcessInfo.processInfo.environment["CUS_DIAGNOSTIC_LOG"] == "1" {
            print("runtime=\(sanitizedState)")
            fflush(stdout)
        }
    }

    private func writeRuntimeState(_ state: String) {
        guard let runtimeStateURL else {
            return
        }
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        let value = [
            "pid=\(ProcessInfo.processInfo.processIdentifier)",
            "version=\(version)",
            "updated=\(Int(Date().timeIntervalSince1970))",
            "runtime=\(state)"
        ].joined(separator: " ") + "\n"
        try? Data(value.utf8).write(to: runtimeStateURL, options: .atomic)
    }

    private func hideOverlay() {
        overlay.hide()
    }

    @objc
    private func applicationActivated(_ notification: Notification) {
        guard
            let application = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication
        else {
            hideOverlay()
            return
        }
        switch ActivationVisibilityPolicy.decision(
            activatedBundleIdentifier: application.bundleIdentifier,
            hostBundleIdentifier: "com.openai.codex",
            companionBundleIdentifier: Bundle.main.bundleIdentifier
                ?? "com.jace.codex-usage-sidebar"
        ) {
        case .reconcileHost:
            reconcileHost()
            refreshNow(reason: .focus)
            reconcileOverlay()
        case .preserve:
            break
        case .hide:
            hideOverlay()
        }
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
        reconcileLanguage()
        reconcileOverlay()
    }
}
