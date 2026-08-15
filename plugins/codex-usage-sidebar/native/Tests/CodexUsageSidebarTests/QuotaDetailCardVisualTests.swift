import AppKit
import SidebarCore
import XCTest
@testable import CodexUsageSidebar

@MainActor
final class QuotaDetailCardVisualTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_786_800_000)
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testRendersEveryLocalizedThemeFixtureWithFixedInformationBand() throws {
        let outputDirectory = ProcessInfo.processInfo.environment[
            "CUS_VISUAL_OUTPUT_DIR"
        ].map(URL.init(fileURLWithPath:))
        if let outputDirectory {
            try FileManager.default.createDirectory(
                at: outputDirectory,
                withIntermediateDirectories: true
            )
        }

        for (language, languageName, expectedLinkLabel) in languages {
            let content = QuotaDetailFormatter().content(
                snapshot: longBankSnapshot,
                tokenUsage: tokenUsageSnapshot,
                now: now,
                language: language,
                timeZone: timeZone
            )
            let rowHeights = Array(
                repeating: QuotaDetailLayout.rowHeight,
                count: content.rows.count
            )
            let cardHeight = QuotaDetailLayout.contentHeight(
                rowContentHeight: rowHeights.reduce(0, +),
                tokenUsageVisible: true
            )

            for (appearanceName, appearance) in appearances {
                var renderedCard: QuotaDetailCardView?
                appearance.performAsCurrentDrawingAppearance {
                    renderedCard = QuotaDetailCardView(
                        frame: CGRect(
                            x: 0,
                            y: 0,
                            width: QuotaDetailLayout.width,
                            height: cardHeight
                        ),
                        content: content,
                        rowHeights: rowHeights,
                        version: "0.3.0",
                        onOpenURL: { _ in }
                    )
                    renderedCard?.appearance = appearance
                }
                let card = try XCTUnwrap(renderedCard)
                card.layoutSubtreeIfNeeded()

                let link = try XCTUnwrap(
                    descendants(of: card)
                        .compactMap { $0 as? QuotaInformationLinkButton }
                        .first
                )
                XCTAssertEqual(link.accessibilityLabel(), expectedLinkLabel)
                XCTAssertEqual(
                    link.frame,
                    QuotaDetailLayout.informationFrames(
                        in: card.bounds,
                        tokenUsageVisible: true
                    ).control
                )

                let tokenView = try XCTUnwrap(
                    descendants(of: card)
                        .compactMap { $0 as? QuotaTokenUsageView }
                        .first
                )
                XCTAssertEqual(tokenView.barCount, 7)
                let tokenScroller = try XCTUnwrap(
                    descendants(of: tokenView)
                        .compactMap { $0 as? NSScrollView }
                        .first
                )
                XCTAssertFalse(tokenScroller.hasHorizontalScroller)

                let scrollView = try XCTUnwrap(
                    descendants(of: card)
                        .compactMap { $0 as? NSScrollView }
                        .first { $0.hasVerticalScroller }
                )
                XCTAssertTrue(scrollView.hasVerticalScroller)

                let png = try renderPNG(card)
                XCTAssertGreaterThan(png.count, 1_000)
                if let outputDirectory {
                    try png.write(
                        to: outputDirectory.appendingPathComponent(
                            "tibo-\(languageName)-\(appearanceName).png"
                        )
                    )
                }

                let hoverEvent = try XCTUnwrap(
                    NSEvent.mouseEvent(
                        with: .mouseMoved,
                        location: CGPoint(x: link.bounds.midX, y: link.bounds.midY),
                        modifierFlags: [],
                        timestamp: 0,
                        windowNumber: 0,
                        context: nil,
                        eventNumber: 0,
                        clickCount: 0,
                        pressure: 0
                    )
                )
                appearance.performAsCurrentDrawingAppearance {
                    link.mouseEntered(with: hoverEvent)
                }
                XCTAssertGreaterThan(
                    link.layer?.backgroundColor?.alpha ?? 0,
                    0.06
                )
                let hoverPNG = try renderPNG(card)
                if let outputDirectory {
                    try hoverPNG.write(
                        to: outputDirectory.appendingPathComponent(
                            "tibo-\(languageName)-\(appearanceName)-hover.png"
                        )
                    )
                }
            }
        }
    }

    func testLongBankRowsStayInsideScrollableViewport() throws {
        let content = QuotaDetailFormatter().content(
            snapshot: longBankSnapshot,
            tokenUsage: tokenUsageSnapshot,
            now: now,
            language: .english,
            timeZone: timeZone
        )
        let rowHeights = Array(
            repeating: QuotaDetailLayout.rowHeight,
            count: content.rows.count
        )
        let card = QuotaDetailCardView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: QuotaDetailLayout.width,
                height: QuotaDetailLayout.maximumHeight
            ),
            content: content,
            rowHeights: rowHeights,
            version: "0.3.0",
            onOpenURL: { _ in }
        )
        card.layoutSubtreeIfNeeded()

        let scrollView = try XCTUnwrap(
            descendants(of: card)
                .compactMap { $0 as? NSScrollView }
                .first { $0.hasVerticalScroller }
        )
        let rowDocument = try XCTUnwrap(scrollView.documentView)
        let rightmostTextEdge = try XCTUnwrap(
            rowDocument.subviews
                .compactMap { ($0 as? NSTextField)?.frame.maxX }
                .max()
        )

        XCTAssertTrue(scrollView.hasVerticalScroller)
        XCTAssertEqual(
            rowDocument.frame.width,
            scrollView.contentSize.width,
            accuracy: 0.5
        )
        XCTAssertLessThanOrEqual(
            rightmostTextEdge,
            scrollView.contentSize.width
        )
    }

    private var languages: [
        (CodexDisplayLanguage, String, String)
    ] {
        [
            (
                .simplifiedChinese,
                "zh-cn",
                "在浏览器中打开 Tibo 的 X 主页"
            ),
            (
                .traditionalChinese,
                "zh-tw",
                "在瀏覽器中開啟 Tibo 的 X 主頁"
            ),
            (
                .english,
                "en",
                "Open Tibo's X profile in the browser"
            )
        ]
    }

    private var appearances: [(String, NSAppearance)] {
        [
            ("light", NSAppearance(named: .aqua)!),
            ("dark", NSAppearance(named: .darkAqua)!)
        ]
    }

    private var longBankSnapshot: AllowanceSnapshot {
        AllowanceSnapshot(
            usedPercent: 68,
            remainingPercent: 32,
            resetsAt: now.addingTimeInterval(86_400),
            receivedAt: now.addingTimeInterval(-20),
            windowDurationMins: 10_080,
            planType: "plus",
            credits: CreditBalance(
                hasCredits: true,
                unlimited: false,
                balance: "12.50"
            ),
            bank: BankResetSummary(
                availableCount: 12,
                credits: (1 ... 12).map { index in
                    BankResetCredit(
                        status: "available",
                        grantedAt: now.addingTimeInterval(
                            -Double(index) * 86_400
                        ),
                        expiresAt: now.addingTimeInterval(
                            Double(index + 1) * 86_400 + 6 * 3_600
                        ),
                        title: "Full reset",
                        description: nil
                    )
                }
            )
        )
    }

    private var tokenUsageSnapshot: TokenUsageSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        return TokenUsageSnapshot(
            receivedAt: now,
            dailyBuckets: (0 ..< 7).map { offset in
                TokenUsageDay(
                    date: calendar.date(
                        byAdding: .day,
                        value: offset - 6,
                        to: today
                    )!,
                    tokens: Int64(80_000 + offset * 40_000),
                    timeZone: timeZone
                )
            },
            summary: nil,
            availability: .available
        )
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    private func renderPNG(_ view: NSView) throws -> Data {
        let representation = try XCTUnwrap(
            view.bitmapImageRepForCachingDisplay(in: view.bounds)
        )
        view.cacheDisplay(in: view.bounds, to: representation)
        return try XCTUnwrap(
            representation.representation(using: .png, properties: [:])
        )
    }
}
