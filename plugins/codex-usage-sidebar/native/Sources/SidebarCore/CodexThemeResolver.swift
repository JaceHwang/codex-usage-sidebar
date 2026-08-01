import Foundation

public enum CodexAppearancePreference: String, Equatable, Sendable {
    case system
    case light
    case dark
}

public enum CodexInterfaceTheme: String, Equatable, Sendable {
    case light
    case dark
}

public enum CodexThemeResolver {
    public static func preference(in contents: String) -> CodexAppearancePreference {
        var isDesktopSection = false

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = stripInlineComment(from: rawLine)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("["), line.hasSuffix("]") {
                let section = line.dropFirst().dropLast()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                isDesktopSection = section == "desktop"
                continue
            }
            guard isDesktopSection else {
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
                    "appearanceTheme"
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
                return .system
            }
            let unquoted = String(value.dropFirst().dropLast())
            return CodexAppearancePreference(rawValue: unquoted) ?? .system
        }

        return .system
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

    public static func resolve(
        preference: CodexAppearancePreference,
        systemIsDark: Bool
    ) -> CodexInterfaceTheme {
        switch preference {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            systemIsDark ? .dark : .light
        }
    }
}

public struct CodexThemeProvider: Sendable {
    private let configurationURL: URL

    public init(configurationURL: URL) {
        self.configurationURL = configurationURL
    }

    public func currentTheme(systemIsDark: Bool) -> CodexInterfaceTheme {
        let contents = (
            try? String(contentsOf: configurationURL, encoding: .utf8)
        ) ?? ""
        return CodexThemeResolver.resolve(
            preference: CodexThemeResolver.preference(in: contents),
            systemIsDark: systemIsDark
        )
    }
}
