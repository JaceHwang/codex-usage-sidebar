import Darwin
import Foundation
import SidebarCore

@MainActor
final class CodexEffectiveLanguageProvider {
    private let userDataDirectory: URL
    private let preferencesURL: URL
    private let configurationProvider: CodexConfigurationLanguageProvider
    private let processReader: CodexProcessArgumentReader

    init(
        userDataDirectory: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Codex"),
        preferencesURL: URL? = nil,
        configurationURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/config.toml"),
        processReader: CodexProcessArgumentReader = .init()
    ) {
        self.userDataDirectory = userDataDirectory
        self.preferencesURL = preferencesURL ?? userDataDirectory
            .appendingPathComponent("Default/Preferences")
        configurationProvider = CodexConfigurationLanguageProvider(
            configurationURL: configurationURL
        )
        self.processReader = processReader
    }

    func currentLanguage() -> CodexResolvedLanguage? {
        CodexLanguageResolver.resolve(
            configurationLocale: configurationProvider
                .currentLocaleIdentifier(),
            processLocale: CodexProcessLocaleSelector.localeIdentifier(
                in: processReader.codexRendererProcesses(),
                userDataDirectory: userDataDirectory.path
            ),
            preferencesLocale: preferencesLocaleIdentifier(),
            systemLocale: Locale.preferredLanguages.first
        )
    }

    private func preferencesLocaleIdentifier() -> String? {
        guard let data = try? Data(contentsOf: preferencesURL) else {
            return nil
        }
        return CodexPreferencesLanguageParser.localeIdentifier(in: data)
    }
}

struct CodexProcessArgumentReader {
    func codexRendererProcesses() -> [CodexProcessDescriptor] {
        processIdentifiers().compactMap { processIdentifier in
            guard
                let path = executablePath(for: processIdentifier),
                path.contains("/Codex (Renderer).app/")
            else {
                return nil
            }
            return CodexProcessDescriptor(
                executablePath: path,
                arguments: arguments(for: processIdentifier) ?? []
            )
        }
    }

    private func processIdentifiers() -> [pid_t] {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else {
            return []
        }
        var values = [pid_t](
            repeating: 0,
            count: Int(estimatedCount) + 32
        )
        let byteCount = Int32(values.count * MemoryLayout<pid_t>.stride)
        let actualCount = values.withUnsafeMutableBytes { bytes in
            proc_listallpids(bytes.baseAddress, byteCount)
        }
        guard actualCount > 0 else {
            return []
        }
        return Array(values.prefix(Int(actualCount))).filter { $0 > 0 }
    }

    private func executablePath(for processIdentifier: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4_096)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_pidpath(
                processIdentifier,
                pointer.baseAddress,
                UInt32(pointer.count)
            )
        }
        guard length > 0 else {
            return nil
        }
        let pathBytes = buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
        return String(decoding: pathBytes, as: UTF8.self)
    }

    private func arguments(for processIdentifier: pid_t) -> [String]? {
        var mib = [CTL_KERN, KERN_PROCARGS2, processIdentifier]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }
        var bytes = [UInt8](repeating: 0, count: size)
        guard
            sysctl(&mib, 3, &bytes, &size, nil, 0) == 0,
            size >= MemoryLayout<Int32>.size
        else {
            return nil
        }
        bytes.removeSubrange(size..<bytes.count)

        let argumentCount = bytes.withUnsafeBytes {
            $0.loadUnaligned(as: Int32.self)
        }
        guard argumentCount > 0 else {
            return []
        }

        var cursor = MemoryLayout<Int32>.size
        skipCString(in: bytes, cursor: &cursor)
        skipZeros(in: bytes, cursor: &cursor)

        var result: [String] = []
        while cursor < bytes.count, result.count < Int(argumentCount) {
            let start = cursor
            skipCString(in: bytes, cursor: &cursor)
            guard cursor > start else {
                break
            }
            let end = max(start, cursor - 1)
            if let value = String(bytes: bytes[start..<end], encoding: .utf8) {
                result.append(value)
            }
            skipZeros(in: bytes, cursor: &cursor)
        }
        return result
    }

    private func skipCString(in bytes: [UInt8], cursor: inout Int) {
        while cursor < bytes.count, bytes[cursor] != 0 {
            cursor += 1
        }
        if cursor < bytes.count {
            cursor += 1
        }
    }

    private func skipZeros(in bytes: [UInt8], cursor: inout Int) {
        while cursor < bytes.count, bytes[cursor] == 0 {
            cursor += 1
        }
    }
}
