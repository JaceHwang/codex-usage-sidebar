import Foundation

public enum CodexDisplayLanguage: String, Equatable, Sendable {
    case simplifiedChinese
    case traditionalChinese
    case english
}

public enum CodexLanguageSource: String, Equatable, Sendable {
    case configuration
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
        configurationLocale: String? = nil,
        processLocale: String?,
        preferencesLocale: String?,
        systemLocale: String?
    ) -> CodexResolvedLanguage? {
        let candidates: [(String?, CodexLanguageSource)] = [
            (configurationLocale, .configuration),
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

public enum CodexConfigurationLanguageParser {
    public static func localeIdentifier(in contents: String) -> String? {
        var currentSection: String?

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = stripInlineComment(from: rawLine)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("["), line.hasSuffix("]") {
                currentSection = String(line.dropFirst().dropLast())
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            guard currentSection == nil || currentSection == "desktop" else {
                continue
            }

            let parts = line.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard
                parts.count == 2,
                parts[0].trimmingCharacters(in: .whitespacesAndNewlines) ==
                    "localeOverride"
            else {
                continue
            }

            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                value.count >= 2,
                let quote = value.first,
                (quote == "\"" || quote == "'"),
                value.last == quote
            else {
                return nil
            }
            let locale = String(value.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return locale.isEmpty ? nil : locale
        }

        return nil
    }

    private static func stripInlineComment(from line: String) -> String {
        var quote: Character?
        var escaped = false

        for index in line.indices {
            let character = line[index]
            if quote == "\"", character == "\\", !escaped {
                escaped = true
                continue
            }
            if character == "\"" || character == "'" {
                if quote == character, !escaped {
                    quote = nil
                } else if quote == nil {
                    quote = character
                }
            } else if character == "#", quote == nil {
                return String(line[..<index])
            }
            escaped = false
        }

        return line
    }
}

public struct CodexConfigurationLanguageProvider: Sendable {
    private let configurationURL: URL

    public init(configurationURL: URL) {
        self.configurationURL = configurationURL
    }

    public func currentLocaleIdentifier() -> String? {
        guard
            let contents = try? String(
                contentsOf: configurationURL,
                encoding: .utf8
            )
        else {
            return nil
        }
        return CodexConfigurationLanguageParser.localeIdentifier(in: contents)
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
