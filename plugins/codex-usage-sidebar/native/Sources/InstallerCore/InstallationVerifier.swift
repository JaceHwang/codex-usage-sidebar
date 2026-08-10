import Foundation

public enum InstallationIssue: Hashable, Sendable {
    case statusCommandFailed
    case managedProcessMissing
    case versionMismatch
    case runtimeStateMissing
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
        commandSucceeded: Bool
    ) -> InstallationReport {
        let fields = Dictionary(
            uniqueKeysWithValues: statusOutput
                .split(whereSeparator: { $0.isWhitespace })
                .compactMap { token -> (String, String)? in
                    let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { return nil }
                    return (parts[0], parts[1])
                }
        )
        let pid = fields["pid"].flatMap(Int.init)
        let version = fields["version"]
        var issues: [InstallationIssue] = []
        if !commandSucceeded {
            issues.append(.statusCommandFailed)
        }
        if pid == nil {
            issues.append(.managedProcessMissing)
        }
        if version != expectedVersion {
            issues.append(.versionMismatch)
        }
        if fields["runtime"] == nil {
            issues.append(.runtimeStateMissing)
        }
        return InstallationReport(pid: pid, version: version, issues: issues)
    }
}

public enum MarketplaceInspector {
    public static func containsSidebarMarketplace(in json: String) throws -> Bool {
        let response = try JSONDecoder().decode(
            MarketplaceList.self,
            from: Data(json.utf8)
        )
        return response.marketplaces.contains {
            $0.name == InstallerCommandPlan.marketplaceName
        }
    }
}

private struct MarketplaceList: Decodable {
    struct Marketplace: Decodable {
        let name: String
    }

    let marketplaces: [Marketplace]
}
