import Foundation

public struct CodexProcessDescriptor: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(executablePath: String, arguments: [String]) {
        self.executablePath = executablePath
        self.arguments = arguments
    }
}

public enum CodexProcessLocaleSelector {
    public static func localeIdentifier(
        in processes: [CodexProcessDescriptor],
        userDataDirectory: String
    ) -> String? {
        let expectedDirectory = normalizedPath(userDataDirectory)

        for process in processes where isCodexRenderer(process.executablePath) {
            guard
                argumentValue(named: "type", in: process.arguments) ==
                    "renderer",
                let processDirectory = argumentValue(
                    named: "user-data-dir",
                    in: process.arguments
                ),
                normalizedPath(processDirectory) == expectedDirectory,
                let locale = argumentValue(
                    named: "lang",
                    in: process.arguments
                )?.trimmingCharacters(in: .whitespacesAndNewlines),
                !locale.isEmpty
            else {
                continue
            }
            return locale
        }
        return nil
    }

    private static func isCodexRenderer(_ executablePath: String) -> Bool {
        let isOfficialApp = executablePath.contains("/ChatGPT.app/") ||
            executablePath.contains("/Codex.app/")
        return isOfficialApp && executablePath.contains(
            "/Codex (Renderer).app/Contents/MacOS/Codex (Renderer)"
        )
    }

    private static func argumentValue(
        named name: String,
        in arguments: [String]
    ) -> String? {
        let option = "--\(name)"
        let prefix = "\(option)="
        for (index, argument) in arguments.enumerated() {
            if argument.hasPrefix(prefix) {
                return String(argument.dropFirst(prefix.count))
            }
            if argument == option, arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
        }
        return nil
    }

    private static func normalizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
