import Foundation
import SidebarCore
import XCTest

final class CodexLanguageResolverTests: XCTestCase {
    func testExplicitConfigurationLocaleWinsOverStaleRendererLocale() {
        XCTAssertEqual(
            CodexLanguageResolver.resolve(
                configurationLocale: "en-US",
                processLocale: "zh-CN",
                preferencesLocale: "zh-CN",
                systemLocale: "zh-CN"
            ),
            CodexResolvedLanguage(
                language: .english,
                source: .configuration
            )
        )
    }

    func testAutomaticLanguageStillUsesEffectiveRendererLocale() {
        XCTAssertEqual(
            CodexLanguageResolver.resolve(
                configurationLocale: nil,
                processLocale: "zh-TW",
                preferencesLocale: "zh-CN",
                systemLocale: "en-US"
            ),
            CodexResolvedLanguage(
                language: .traditionalChinese,
                source: .process
            )
        )
    }

    func testParsesQuotedDesktopLocaleOverride() {
        let text = """
        [desktop]
        localeOverride = "en-US" # current Codex setting

        [marketplaces.openai-bundled]
        localeOverride = "zh-CN"
        """

        XCTAssertEqual(
            CodexConfigurationLanguageParser.localeIdentifier(in: text),
            "en-US"
        )
        XCTAssertEqual(
            CodexConfigurationLanguageParser.localeIdentifier(
                in: "[desktop]\nlocaleOverride = 'zh-TW'"
            ),
            "zh-TW"
        )
    }

    func testRejectsMissingUnrelatedMalformedAndEmptyLocaleOverrides() {
        let values = [
            "",
            "[marketplaces.example]\nlocaleOverride = \"en-US\"",
            "[desktop]\nlocaleOverride = en-US",
            "[desktop]\nlocaleOverride = \"\"",
            "[desktop]\nlocaleOverride = 42"
        ]

        for value in values {
            XCTAssertNil(
                CodexConfigurationLanguageParser.localeIdentifier(in: value)
            )
        }
    }

    func testConfigurationProviderRereadsLiveChangesAndMissingMeansAuto() throws {
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
        let provider = CodexConfigurationLanguageProvider(
            configurationURL: url
        )

        XCTAssertNil(provider.currentLocaleIdentifier())
        try "[desktop]\nlocaleOverride = \"en-US\"".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        XCTAssertEqual(provider.currentLocaleIdentifier(), "en-US")
        try "# Auto mode has no locale override".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        XCTAssertNil(provider.currentLocaleIdentifier())
    }

    func testMapsScriptsRegionsAndUnsupportedLocales() {
        let cases: [(String, CodexDisplayLanguage)] = [
            ("zh-Hans-CN", .simplifiedChinese),
            ("zh_SG", .simplifiedChinese),
            ("zh", .simplifiedChinese),
            ("zh-Hant-HK", .traditionalChinese),
            ("zh_TW", .traditionalChinese),
            ("zh-MO", .traditionalChinese),
            ("en-GB", .english),
            ("ja-JP", .english)
        ]

        for (identifier, expected) in cases {
            XCTAssertEqual(
                CodexLanguageResolver.map(identifier),
                expected,
                "unexpected mapping for \(identifier)"
            )
        }
    }

    func testScriptSubtagWinsOverConflictingRegion() {
        XCTAssertEqual(
            CodexLanguageResolver.map("zh-Hant-CN"),
            .traditionalChinese
        )
        XCTAssertEqual(
            CodexLanguageResolver.map("zh-Hans-TW"),
            .simplifiedChinese
        )
    }

    func testProcessLocaleWinsOverPreferencesAndSystem() {
        XCTAssertEqual(
            CodexLanguageResolver.resolve(
                processLocale: "zh-TW",
                preferencesLocale: "zh-CN",
                systemLocale: "en-US"
            ),
            CodexResolvedLanguage(
                language: .traditionalChinese,
                source: .process
            )
        )
    }

    func testRunningUnsupportedLocaleWinsAndMapsToEnglish() {
        XCTAssertEqual(
            CodexLanguageResolver.resolve(
                processLocale: "ja-JP",
                preferencesLocale: "zh-CN",
                systemLocale: "zh-TW"
            ),
            CodexResolvedLanguage(language: .english, source: .process)
        )
    }

    func testFallsBackThroughEmptyCandidatesAndReturnsNilWithoutAnyLocale() {
        XCTAssertEqual(
            CodexLanguageResolver.resolve(
                processLocale: "  ",
                preferencesLocale: "zh-CN",
                systemLocale: "en-US"
            ),
            CodexResolvedLanguage(
                language: .simplifiedChinese,
                source: .preferences
            )
        )
        XCTAssertEqual(
            CodexLanguageResolver.resolve(
                processLocale: nil,
                preferencesLocale: nil,
                systemLocale: "zh-HK"
            ),
            CodexResolvedLanguage(
                language: .traditionalChinese,
                source: .system
            )
        )
        XCTAssertNil(
            CodexLanguageResolver.resolve(
                processLocale: nil,
                preferencesLocale: "",
                systemLocale: nil
            )
        )
    }

    func testParsesFirstSelectedLanguageFromCodexPreferences() {
        let data = Data(
            #"{"intl":{"selected_languages":"zh-TW,zh,en-US"}}"#.utf8
        )

        XCTAssertEqual(
            CodexPreferencesLanguageParser.localeIdentifier(in: data),
            "zh-TW"
        )
    }

    func testRejectsMissingMalformedWrongTypeAndEmptyPreferences() {
        let values = [
            Data(),
            Data("not json".utf8),
            Data(#"{}"#.utf8),
            Data(#"{"intl":{"selected_languages":42}}"#.utf8),
            Data(#"{"intl":{"selected_languages":" , "}}"#.utf8)
        ]

        for data in values {
            XCTAssertNil(
                CodexPreferencesLanguageParser.localeIdentifier(in: data)
            )
        }
    }
}
