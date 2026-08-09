import SidebarCore
import XCTest

final class RuntimeLanguageStateTests: XCTestCase {
    func testStartsInEnglishWithoutAResolvedCodexLocale() {
        let state = RuntimeLanguageState()

        XCTAssertEqual(state.language, .english)
        XCTAssertNil(state.source)
    }

    func testAppliesLanguageChangeAndTracksItsSource() {
        var state = RuntimeLanguageState()

        XCTAssertTrue(
            state.apply(
                CodexResolvedLanguage(
                    language: .traditionalChinese,
                    source: .process
                )
            )
        )
        XCTAssertEqual(state.language, .traditionalChinese)
        XCTAssertEqual(state.source, .process)
    }

    func testRetainsLastLanguageWhenDetectionTemporarilyFails() {
        var state = RuntimeLanguageState(initial: .english)
        XCTAssertTrue(
            state.apply(
                CodexResolvedLanguage(
                    language: .traditionalChinese,
                    source: .process
                )
            )
        )

        XCTAssertFalse(state.apply(nil))
        XCTAssertEqual(state.language, .traditionalChinese)
        XCTAssertEqual(state.source, .process)
    }

    func testSameLanguageUpdatesSourceWithoutRequestingUIRefresh() {
        var state = RuntimeLanguageState(initial: .simplifiedChinese)

        XCTAssertFalse(
            state.apply(
                CodexResolvedLanguage(
                    language: .simplifiedChinese,
                    source: .preferences
                )
            )
        )
        XCTAssertEqual(state.language, .simplifiedChinese)
        XCTAssertEqual(state.source, .preferences)
    }
}
