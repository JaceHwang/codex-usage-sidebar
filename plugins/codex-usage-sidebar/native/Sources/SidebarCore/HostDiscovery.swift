import AppKit
import Foundation

public enum HostSource: String, Equatable, Sendable {
    case runningBundle
    case applicationsBundle
    case path
}

public struct HostInstallation: Equatable, Sendable {
    public let appServerExecutableURL: URL
    public let bundleURL: URL?
    public let bundleVersion: String?
    public let buildIdentity: String
    public let source: HostSource
    public let processIdentifier: pid_t?

    public init(
        appServerExecutableURL: URL,
        bundleURL: URL?,
        bundleVersion: String?,
        buildIdentity: String,
        source: HostSource,
        processIdentifier: pid_t?
    ) {
        self.appServerExecutableURL = appServerExecutableURL
        self.bundleURL = bundleURL
        self.bundleVersion = bundleVersion
        self.buildIdentity = buildIdentity
        self.source = source
        self.processIdentifier = processIdentifier
    }
}

public struct HostDiscovery: Sendable {
    private let runningBundleURL: URL?
    private let runningProcessIdentifier: pid_t?
    private let applicationBundleURL: URL
    private let path: String

    public init(
        runningBundleURL: URL?,
        runningProcessIdentifier: pid_t? = nil,
        applicationBundleURL: URL,
        path: String
    ) {
        self.runningBundleURL = runningBundleURL
        self.runningProcessIdentifier = runningProcessIdentifier
        self.applicationBundleURL = applicationBundleURL
        self.path = path
    }

    public func current() -> HostInstallation? {
        if
            let runningBundleURL,
            let installation = installation(
                bundleURL: runningBundleURL,
                source: .runningBundle,
                processIdentifier: runningProcessIdentifier
            )
        {
            return installation
        }

        if let installation = installation(
            bundleURL: applicationBundleURL,
            source: .applicationsBundle,
            processIdentifier: nil
        ) {
            return installation
        }

        for directory in path.split(separator: ":").map(String.init) where !directory.isEmpty {
            let executable = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent("codex")
            if FileManager.default.isExecutableFile(atPath: executable.path) {
                return installation(
                    executableURL: executable,
                    bundleURL: nil,
                    source: .path,
                    processIdentifier: nil
                )
            }
        }
        return nil
    }

    @MainActor
    public static func current() -> HostInstallation? {
        let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.openai.codex")
            .first
        let discovery = HostDiscovery(
            runningBundleURL: running?.bundleURL,
            runningProcessIdentifier: running?.processIdentifier,
            applicationBundleURL: URL(
                fileURLWithPath: "/Applications/ChatGPT.app",
                isDirectory: true
            ),
            path: ProcessInfo.processInfo.environment["PATH"] ?? ""
        )
        return discovery.current()
    }

    private func installation(
        bundleURL: URL,
        source: HostSource,
        processIdentifier: pid_t?
    ) -> HostInstallation? {
        let executable = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("codex")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            return nil
        }
        return installation(
            executableURL: executable,
            bundleURL: bundleURL,
            source: source,
            processIdentifier: processIdentifier
        )
    }

    private func installation(
        executableURL: URL,
        bundleURL: URL?,
        source: HostSource,
        processIdentifier: pid_t?
    ) -> HostInstallation? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: executableURL.path
            ),
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }

        let modification = (attributes[.modificationDate] as? Date)?
            .timeIntervalSince1970 ?? 0
        let plist = bundleURL.flatMap(readInfoPlist)
        let shortVersion = plist?["CFBundleShortVersionString"] as? String
        let buildVersion = plist?["CFBundleVersion"] as? String
        let versionIdentity = [
            shortVersion ?? "cli",
            buildVersion ?? "unversioned"
        ].joined(separator: "+")
        let buildIdentity = [
            versionIdentity,
            String(size.int64Value),
            String(Int64(modification))
        ].joined(separator: "|")

        return HostInstallation(
            appServerExecutableURL: executableURL,
            bundleURL: bundleURL,
            bundleVersion: shortVersion,
            buildIdentity: buildIdentity,
            source: source,
            processIdentifier: processIdentifier
        )
    }

    private func readInfoPlist(bundleURL: URL) -> [String: Any]? {
        let url = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
        else {
            return nil
        }
        return plist as? [String: Any]
    }
}
