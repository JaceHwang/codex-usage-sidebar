import Foundation

public enum InstallationIssue: Hashable, Sendable {
    case statusCommandFailed
    case managedProcessMissing
    case versionMismatch
    case runtimeStateMissing
    case runtimeStateUnhealthy
    case codexLoginMissing
    case accessibilityCheckFailed
    case accessibilityNotGranted
    case codexHostMissing
    case appServerMissing
}

public struct InstallationReport: Equatable, Sendable {
    public let pid: Int?
    public let version: String?
    public let issues: [InstallationIssue]

    public var isHealthy: Bool {
        issues.isEmpty
    }
}

public enum InstallationVerifier {
    public static func evaluate(
        statusOutput: String,
        expectedVersion: String,
        statusCommandSucceeded: Bool,
        loginCommandSucceeded: Bool,
        accessibilityOutput: String,
        accessibilityCommandSucceeded: Bool
    ) -> InstallationReport {
        let statusFields = fields(in: statusOutput)
        let accessibilityFields = fields(in: accessibilityOutput)
        let pid = statusFields["pid"].flatMap(Int.init)
        let version = statusFields["version"]
        let runtime = statusFields["runtime"]
        var issues: [InstallationIssue] = []
        if !statusCommandSucceeded {
            issues.append(.statusCommandFailed)
        }
        if pid == nil {
            issues.append(.managedProcessMissing)
        }
        if version != expectedVersion {
            issues.append(.versionMismatch)
        }
        if runtime == nil {
            issues.append(.runtimeStateMissing)
        } else if runtime != "shown" && runtime != "hidden:not-foreground" {
            issues.append(.runtimeStateUnhealthy)
        }
        if !loginCommandSucceeded {
            issues.append(.codexLoginMissing)
        }
        if !accessibilityCommandSucceeded {
            issues.append(.accessibilityCheckFailed)
        }
        if accessibilityFields["accessibility"] != "granted" {
            issues.append(.accessibilityNotGranted)
        }
        if accessibilityFields["host"] != "found" {
            issues.append(.codexHostMissing)
        }
        if accessibilityFields["app_server"] != "found" {
            issues.append(.appServerMissing)
        }
        return InstallationReport(pid: pid, version: version, issues: issues)
    }

    public static func evaluate(
        statusOutput: String,
        expectedVersion: String,
        commandSucceeded: Bool
    ) -> InstallationReport {
        evaluate(
            statusOutput: statusOutput,
            expectedVersion: expectedVersion,
            statusCommandSucceeded: commandSucceeded,
            loginCommandSucceeded: false,
            accessibilityOutput: "",
            accessibilityCommandSucceeded: false
        )
    }

    private static func fields(in output: String) -> [String: String] {
        output
            .split(whereSeparator: { $0.isWhitespace })
            .reduce(into: [:]) { result, token in
                let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                result[parts[0]] = parts[1]
            }
    }
}

public enum MarketplaceConfiguration: Equatable, Sendable {
    case absent
    case installerOwned
    case conflict(root: String?)
}

public enum MarketplaceInspector {
    public static func containsSidebarMarketplace(in json: String) throws -> Bool {
        let response = try decode(json)
        return response.marketplaces.contains {
            $0.name == InstallerCommandPlan.marketplaceName
        }
    }

    public static func sidebarMarketplaceRoot(in json: String) throws -> String? {
        try decode(json).marketplaces.first {
            $0.name == InstallerCommandPlan.marketplaceName
        }?.root
    }

    public static func configuration(
        in json: String,
        expectedRoot: URL
    ) throws -> MarketplaceConfiguration {
        let matches = try decode(json).marketplaces.filter {
            $0.name == InstallerCommandPlan.marketplaceName
        }
        guard matches.count == 1 else {
            return matches.isEmpty ? .absent : .conflict(root: matches.first?.root)
        }
        guard let root = matches[0].root else {
            return .conflict(root: nil)
        }
        let configured = URL(fileURLWithPath: root)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let expected = expectedRoot
            .standardizedFileURL
            .resolvingSymlinksInPath()
        return configured.path == expected.path ? .installerOwned : .conflict(root: root)
    }

    private static func decode(_ json: String) throws -> MarketplaceList {
        try JSONDecoder().decode(MarketplaceList.self, from: Data(json.utf8))
    }
}

private struct MarketplaceList: Decodable {
    struct Marketplace: Decodable {
        let name: String
        let root: String?
    }

    let marketplaces: [Marketplace]
}
