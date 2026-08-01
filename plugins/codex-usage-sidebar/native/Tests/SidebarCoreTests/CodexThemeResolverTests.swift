import Foundation
import XCTest
@testable import SidebarCore

final class CodexThemeResolverTests: XCTestCase {
    func testReadsOnlyDesktopAppearanceTheme() {
        let text = """
        [plugins.example]
        appearanceTheme = "dark"

        [desktop]
          appearanceTheme = "light" # active setting
        """

        XCTAssertEqual(CodexThemeResolver.preference(in: text), .light)
    }

    func testSupportsAllValuesAndFallsBackToSystem() {
        XCTAssertEqual(
            CodexThemeResolver.preference(
                in: "[desktop]\nappearanceTheme = \"dark\""
            ),
            .dark
        )
        XCTAssertEqual(
            CodexThemeResolver.preference(
                in: "[desktop]\nappearanceTheme = \"system\""
            ),
            .system
        )
        XCTAssertEqual(
            CodexThemeResolver.preference(
                in: "[desktop]\nappearanceTheme = \"sepia\""
            ),
            .system
        )
        XCTAssertEqual(
            CodexThemeResolver.preference(
                in: "[other]\nappearanceTheme = \"light\""
            ),
            .system
        )
    }

    func testRequiresValidQuotedTomlString() {
        XCTAssertEqual(
            CodexThemeResolver.preference(
                in: "[desktop]\nappearanceTheme = dark"
            ),
            .system
        )
        XCTAssertEqual(
            CodexThemeResolver.preference(
                in: "[desktop]\nappearanceTheme = 'light' # literal string"
            ),
            .light
        )
        XCTAssertEqual(
            CodexThemeResolver.preference(
                in: "[desktop]\nappearanceTheme = \"dark#unexpected\""
            ),
            .system
        )
    }

    func testExplicitPreferenceOverridesSystemAndSystemFollowsIt() {
        XCTAssertEqual(
            CodexThemeResolver.resolve(preference: .light, systemIsDark: true),
            .light
        )
        XCTAssertEqual(
            CodexThemeResolver.resolve(preference: .dark, systemIsDark: false),
            .dark
        )
        XCTAssertEqual(
            CodexThemeResolver.resolve(preference: .system, systemIsDark: true),
            .dark
        )
        XCTAssertEqual(
            CodexThemeResolver.resolve(preference: .system, systemIsDark: false),
            .light
        )
    }

    func testProviderRereadsChangedConfigurationAndMissingFileUsesSystem() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let url = directory.appendingPathComponent("config.toml")
        let provider = CodexThemeProvider(configurationURL: url)

        XCTAssertEqual(provider.currentTheme(systemIsDark: true), .dark)
        try "[desktop]\nappearanceTheme = \"light\"".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        XCTAssertEqual(provider.currentTheme(systemIsDark: true), .light)
        try "[desktop]\nappearanceTheme = \"dark\"".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        XCTAssertEqual(provider.currentTheme(systemIsDark: false), .dark)
    }
}
