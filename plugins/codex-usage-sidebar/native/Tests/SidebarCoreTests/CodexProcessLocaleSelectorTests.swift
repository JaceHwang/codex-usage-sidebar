import SidebarCore
import XCTest

final class CodexProcessLocaleSelectorTests: XCTestCase {
    private let codexData =
        "/Users/test/Library/Application Support/Codex"
    private let rendererPath =
        "/Applications/ChatGPT.app/Contents/Frameworks/" +
        "Codex (Renderer).app/Contents/MacOS/Codex (Renderer)"

    func testSelectsOnlyCodexRendererForExpectedUserDataDirectory() {
        let records = [
            CodexProcessDescriptor(
                executablePath: rendererPath,
                arguments: [
                    "Codex (Renderer)",
                    "--type=renderer",
                    "--user-data-dir=\(codexData)",
                    "--lang=zh-TW"
                ]
            ),
            CodexProcessDescriptor(
                executablePath: "/Applications/Other.app/Other",
                arguments: [
                    "Other",
                    "--type=renderer",
                    "--user-data-dir=\(codexData)",
                    "--lang=ja-JP"
                ]
            )
        ]

        XCTAssertEqual(
            CodexProcessLocaleSelector.localeIdentifier(
                in: records,
                userDataDirectory: codexData
            ),
            "zh-TW"
        )
    }

    func testAcceptsSplitChromiumArguments() {
        let record = CodexProcessDescriptor(
            executablePath: rendererPath,
            arguments: [
                "Codex (Renderer)",
                "--type", "renderer",
                "--user-data-dir", codexData,
                "--lang", "en-US"
            ]
        )

        XCTAssertEqual(
            CodexProcessLocaleSelector.localeIdentifier(
                in: [record],
                userDataDirectory: codexData
            ),
            "en-US"
        )
    }

    func testRejectsWrongDirectoryMissingTypeMissingLanguageAndOtherApp() {
        let records = [
            CodexProcessDescriptor(
                executablePath: rendererPath,
                arguments: [
                    "Codex (Renderer)",
                    "--type=renderer",
                    "--user-data-dir=/tmp/Other",
                    "--lang=zh-CN"
                ]
            ),
            CodexProcessDescriptor(
                executablePath: rendererPath,
                arguments: [
                    "Codex (Renderer)",
                    "--user-data-dir=\(codexData)",
                    "--lang=zh-CN"
                ]
            ),
            CodexProcessDescriptor(
                executablePath: rendererPath,
                arguments: [
                    "Codex (Renderer)",
                    "--type=renderer",
                    "--user-data-dir=\(codexData)"
                ]
            ),
            CodexProcessDescriptor(
                executablePath:
                    "/Applications/Fake.app/Contents/MacOS/Codex (Renderer)",
                arguments: [
                    "Codex (Renderer)",
                    "--type=renderer",
                    "--user-data-dir=\(codexData)",
                    "--lang=zh-CN"
                ]
            )
        ]

        XCTAssertNil(
            CodexProcessLocaleSelector.localeIdentifier(
                in: records,
                userDataDirectory: codexData
            )
        )
    }

    func testNormalizesUserDataDirectoryTrailingSlash() {
        let record = CodexProcessDescriptor(
            executablePath: rendererPath,
            arguments: [
                "Codex (Renderer)",
                "--type=renderer",
                "--user-data-dir=\(codexData)/",
                "--lang=zh-HK"
            ]
        )

        XCTAssertEqual(
            CodexProcessLocaleSelector.localeIdentifier(
                in: [record],
                userDataDirectory: codexData
            ),
            "zh-HK"
        )
    }
}
