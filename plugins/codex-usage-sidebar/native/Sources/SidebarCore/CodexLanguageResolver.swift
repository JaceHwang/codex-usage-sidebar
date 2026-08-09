import Foundation

public enum CodexDisplayLanguage: String, Equatable, Sendable {
    case simplifiedChinese
    case traditionalChinese
    case english
}

public enum CodexLanguageSource: String, Equatable, Sendable {
    case process
    case preferences
    case system
}

public struct CodexResolvedLanguage: Equatable, Sendable {
    public let language: CodexDisplayLanguage
    public let source: CodexLanguageSource

    public init(
        language: CodexDisplayLanguage,
        source: CodexLanguageSource
    ) {
        self.language = language
        self.source = source
    }
}

public enum CodexLanguageResolver {
    public static func map(_ localeIdentifier: String) -> CodexDisplayLanguage {
        let normalized = localeIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        let components = normalized.split(separator: "-").map(String.init)

        guard components.first == "zh" else {
            return .english
        }
        if components.contains("hant") {
            return .traditionalChinese
        }
        if components.contains("hans") {
            return .simplifiedChinese
        }
        if components.contains(where: { ["tw", "hk", "mo"].contains($0) }) {
            return .traditionalChinese
        }
        return .simplifiedChinese
    }

    public static func resolve(
        processLocale: String?,
        preferencesLocale: String?,
        systemLocale: String?
    ) -> CodexResolvedLanguage? {
        let candidates: [(String?, CodexLanguageSource)] = [
            (processLocale, .process),
            (preferencesLocale, .preferences),
            (systemLocale, .system)
        ]
        for (candidate, source) in candidates {
            guard
                let candidate,
                !candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            else {
                continue
            }
            return CodexResolvedLanguage(
                language: map(candidate),
                source: source
            )
        }
        return nil
    }
}

public enum CodexPreferencesLanguageParser {
    public static func localeIdentifier(in data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            let international = root["intl"] as? [String: Any],
            let selected = international["selected_languages"] as? String
        else {
            return nil
        }
        return selected
            .split(separator: ",", omittingEmptySubsequences: false)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
