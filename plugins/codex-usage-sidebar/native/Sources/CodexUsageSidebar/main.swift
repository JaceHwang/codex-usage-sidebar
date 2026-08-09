import AppKit
import Foundation
import SidebarCore

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let runtimeConfiguration = CompanionRuntimeConfiguration(
    arguments: CommandLine.arguments,
    userHomeURL: FileManager.default.homeDirectoryForCurrentUser
)
let appServerEnvironmentOverrides = [
    "CODEX_HOME": runtimeConfiguration.codexHomeURL.path
]
let coordinator = RuntimeCoordinator(
    appServerEnvironmentOverrides: appServerEnvironmentOverrides,
    runtimeStateURL: runtimeConfiguration.pluginDataURL
        .appendingPathComponent("runtime-state.txt")
)

if CommandLine.arguments.contains("--diagnostic-once") {
    print(coordinator.diagnosticSummary())
} else if CommandLine.arguments.contains("--diagnostic-stream-once") {
    if let host = HostDiscovery.current() {
        let client = AppServerClient(
            executableURL: host.appServerExecutableURL,
            environmentOverrides: appServerEnvironmentOverrides
        )
        Task { @MainActor in
            do {
                try await client.start()
                let snapshot = await withTaskGroup(
                    of: AllowanceSnapshot?.self
                ) { group in
                    group.addTask {
                        for await value in client.snapshots {
                            return value
                        }
                        return nil
                    }
                    group.addTask {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        return nil
                    }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first
                }
                if let snapshot {
                    let bankCount = snapshot.bank.map {
                        String($0.availableCount)
                    } ?? "unavailable"
                    let bankExpiry = snapshot.bank?.credits?
                        .compactMap(\.expiresAt)
                        .min()
                        .map {
                            String(Int($0.timeIntervalSince1970))
                        } ?? "none"
                    print(
                        "stream=ok remaining=\(snapshot.remainingPercent) " +
                            "reset_epoch=\(Int(snapshot.resetsAt.timeIntervalSince1970)) " +
                            "bank_count=\(bankCount) " +
                            "bank_earliest_expiry=\(bankExpiry)"
                    )
                } else {
                    print("stream=timeout")
                }
            } catch {
                print("stream=failed")
            }
            await client.stop()
            application.terminate(nil)
        }
        application.run()
    } else {
        print("stream=no-host")
    }
} else {
    coordinator.start()
    application.run()
    coordinator.stop()
}
