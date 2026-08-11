import XCTest
@testable import InstallerCore

final class InstallerPresentationTests: XCTestCase {
    func testWaitingForAccessibilityDoesNotCompleteThePermissionStep() {
        var state = InstallerPresentationState.initial

        state.begin(.accessibility)
        state.waitForUser(.accessibility)

        XCTAssertEqual(state.phase, .waiting(.accessibility))
        XCTAssertFalse(state.completedSteps.contains(.accessibility))
    }

    func testOpeningAccessibilitySettingsAdvancesToExplicitVerifyAction() {
        var state = InstallerPresentationState.initial
        state.waitForUser(.accessibility)

        state.accessibilitySettingsOpened()

        XCTAssertEqual(state.phase, .waiting(.verify))
        XCTAssertFalse(state.completedSteps.contains(.accessibility))
    }

    func testOnlyVerifiedStepsBecomeComplete() {
        var state = InstallerPresentationState.initial

        state.begin(.check)
        state.complete(.check)

        XCTAssertEqual(state.phase, .ready)
        XCTAssertEqual(state.completedSteps, [.check])
    }

    func testLocalizedCopyIncludesUnsignedFinderOpenInstructions() {
        XCTAssertTrue(InstallerCopy.english.finderOpen.contains("right-click"))
        XCTAssertTrue(InstallerCopy.simplifiedChinese.finderOpen.contains("右键"))
        XCTAssertTrue(InstallerCopy.traditionalChinese.finderOpen.contains("右鍵"))
    }

    func testLocaleSelectionSupportsBothChineseScriptsAndEnglishFallback() {
        XCTAssertEqual(InstallerCopy.forLanguageIdentifier("zh-Hans-CN"), .simplifiedChinese)
        XCTAssertEqual(InstallerCopy.forLanguageIdentifier("zh-Hant-TW"), .traditionalChinese)
        XCTAssertEqual(InstallerCopy.forLanguageIdentifier("fr-FR"), .english)
    }
}
