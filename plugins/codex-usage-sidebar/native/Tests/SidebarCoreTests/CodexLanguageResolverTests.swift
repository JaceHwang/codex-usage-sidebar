import Foundation
import SidebarCore
import XCTest

final class CodexLanguageResolverTests: XCTestCase {
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
