import AppKit
import CoreGraphics
import SidebarCore

@MainActor
extension CodexInterfaceTheme {
    var appKitAppearance: NSAppearance {
        if let appearance = NSAppearance(
            named: self == .dark ? .darkAqua : .aqua
        ) {
            return appearance
        }
        return NSApplication.shared.effectiveAppearance
    }
}

@MainActor
final class OverlayPanel: NSObject {
    private final class PassivePanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let panel: NSPanel
    private let interactionView = IndicatorInteractionView(frame: .zero)
    private let textField: NSTextField
    private let indicatorIconView = QuotaThemeIconView(frame: .zero)
    private let pillView = NSView()
    private let detailPanel = QuotaDetailPanel()
    private let positionModePopover = IndicatorPositionModePopover()
    private let detailSettingsMenu = QuotaDetailSettingsMenuPopover()
    private var hoverTimer: Timer?
    private var latestDetail: QuotaDetailContent?
    private var latestTheme: CodexInterfaceTheme = .light
    private var latestLanguage: CodexDisplayLanguage = .english
    private var isIndicatorVisible = false
    private var isHoveringIndicator = false
    private var detailInteraction = QuotaDetailInteractionState()
    private var dragOrigin: CGPoint?
    private var pinnedDetailOutsideGlobalMonitor: Any?
    private var pinnedDetailOutsideLocalMonitor: Any?
    var placementMode: IndicatorPlacementMode = .automatic {
        didSet {
            interactionView.mode = placementMode
            interactionView.window?.invalidateCursorRects(for: interactionView)
        }
    }
    var onPlacementModeSelected: ((IndicatorPlacementMode, CGRect) -> Void)?
    var onIndicatorDragged: ((CGRect) -> CGRect)?
    var onIndicatorDragEnded: ((CGRect) -> Void)?
    var onReloadRequested: (() -> Void)?
    var onQuitRequested: (() -> Void)?

    var isDraggingIndicator: Bool {
        interactionView.isDraggingIndicator
    }
    private lazy var externalLinkActivator = QuotaExternalLinkActivator(
        dismiss: { [weak self] in
            self?.dismissDetailForExternalNavigation()
        },
        open: { destination in
            NSWorkspace.shared.open(destination)
        }
    )

    override init() {
        panel = PassivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        textField = NSTextField(labelWithString: "")
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = interactionView

        pillView.wantsLayer = true
        pillView.layer?.cornerRadius = 10
        pillView.layer?.borderWidth = 0
        indicatorIconView.wantsLayer = true
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.lineBreakMode = .byClipping
        textField.maximumNumberOfLines = 2
        textField.usesSingleLineMode = false
        textField.alignment = .left

        let contentView = interactionView
        detailPanel.onOpenURL = { [weak self] destination in
            self?.externalLinkActivator.activate(destination)
        }
        detailPanel.onSettingsButtonTapped = { [weak self] frame in
            self?.showDetailSettingsMenu(relativeTo: frame)
        }
        pillView.addSubview(indicatorIconView)
        contentView.addSubview(pillView)
        contentView.addSubview(textField)
        interactionView.onPrimaryClick = { [weak self] in
            self?.toggleDetailPin()
        }
        interactionView.onDragBegan = { [weak self] in
            self?.dragOrigin = self?.panel.frame.origin
        }
        interactionView.onDrag = { [weak self] delta in
            self?.dragIndicator(by: delta)
        }
        interactionView.onDragEnded = { [weak self] in
            guard let self else { return }
            self.dragOrigin = nil
            self.onIndicatorDragEnded?(self.panel.frame)
        }
    }

    func show(
        snapshot: AllowanceSnapshot,
        summary: ResetIndicatorSummary,
        indicatorFrame: CGRect,
        theme: CodexInterfaceTheme,
        language: CodexDisplayLanguage,
        detail: QuotaDetailContent,
        dimmed: Bool
    ) {
        let appearance = theme.appKitAppearance
        panel.appearance = appearance
        panel.contentView?.appearance = appearance
        pillView.appearance = appearance
        indicatorIconView.updateAppearance(appearance)
        textField.appearance = appearance
        appearance.performAsCurrentDrawingAppearance {
            textField.attributedStringValue = attributedSummary(
                summary,
                alignment: .left
            )
        }
        latestDetail = detail
        latestTheme = theme
        latestLanguage = language
        isIndicatorVisible = true
        panel.alphaValue = dimmed ? 0.52 : 1
        panel.setFrame(indicatorFrame, display: true)
        interactionView.frame = CGRect(origin: .zero, size: indicatorFrame.size)
        let indicatorBounds = CGRect(origin: .zero, size: indicatorFrame.size)
        let controlSurface = OverlayLayout.controlSurfaceFrame(in: indicatorBounds)
        pillView.isHidden = false
        pillView.frame = controlSurface
        let iconSize = min(20, max(0, controlSurface.height - 8))
        indicatorIconView.frame = CGRect(
            x: 6,
            y: floor((controlSurface.height - iconSize) / 2),
            width: iconSize,
            height: iconSize
        )
        let textHeight = max(
            0,
            min(textField.intrinsicContentSize.height, controlSurface.height)
        )
        textField.frame = CGRect(
            x: controlSurface.minX + iconSize + 12,
            y: controlSurface.minY + floor((controlSurface.height - textHeight) / 2),
            width: max(0, controlSurface.width - iconSize - 20),
            height: textHeight
        )
        updateControlAppearance()
        panel.orderFrontRegardless()
        positionModePopover.reposition(relativeTo: panel.frame)
        updateDetailVisibility()
        startHoverTimerIfNeeded()
    }

    func preferredIndicatorWidth(summary: ResetIndicatorSummary) -> CGFloat {
        let attributed = attributedSummary(summary, alignment: .left)
        let measuredWidth = attributed.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).width
        return OverlayLayout.indicatorWidth(for: measuredWidth)
    }

    func hide() {
        isIndicatorVisible = false
        isHoveringIndicator = false
        detailInteraction.reset()
        removePinnedDetailOutsideMonitors()
        positionModePopover.hide()
        detailSettingsMenu.hide()
        panel.orderOut(nil)
        detailPanel.hide()
    }

    func reposition(to frame: CGRect) {
        guard isIndicatorVisible else {
            return
        }
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        interactionView.frame = CGRect(origin: .zero, size: frame.size)
        // Codex can rebuild/reorder its title-bar views while a side pane is
        // being resized. Reassert the non-activating panel's z-order so the
        // fallback indicator cannot be covered by the host window.
        panel.orderFrontRegardless()
        positionModePopover.reposition(relativeTo: panel.frame)
        updateDetailVisibility()
    }

    private func attributedSummary(
        _ summary: ResetIndicatorSummary,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        OverlayIndicatorTypography.string(
            summary: summary,
            alignment: alignment
        )
    }
}

@MainActor
enum OverlayIndicatorTypography {
    private static let labelColumnWidth: CGFloat = 46
    private static let percentColumnWidth: CGFloat = 78

    static func string(
        summary: ResetIndicatorSummary,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let lines = [
            formattedLine(
                summary.primary,
                remainingPercent: summary.primaryRemainingPercent
            ),
            summary.secondary.flatMap { secondary in
                guard let percent = summary.secondaryRemainingPercent else {
                    return nil
                }
                return formattedLine(secondary, remainingPercent: percent)
            }
        ].compactMap { $0 }
        let label = lines.joined(separator: "\n")
        let result = NSMutableAttributedString(string: label)
        let fullRange = NSRange(location: 0, length: result.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byClipping
        paragraph.lineSpacing = 0
        paragraph.tabStops = [
            NSTextTab(
                textAlignment: .left,
                location: labelColumnWidth,
                options: [:]
            ),
            NSTextTab(
                textAlignment: .left,
                location: percentColumnWidth,
                options: [:]
            )
        ]
        result.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ],
            range: fullRange
        )

        applyPercentStyle(
            to: result,
            label: label,
            remainingPercent: summary.primaryRemainingPercent,
            searchStart: label.startIndex
        )
        if summary.secondary != nil,
           let secondaryPercent = summary.secondaryRemainingPercent,
           let newline = label.firstIndex(of: "\n")
        {
            applyPercentStyle(
                to: result,
                label: label,
                remainingPercent: secondaryPercent,
                searchStart: label.index(after: newline)
            )
        }
        return result
    }

    private static func formattedLine(
        _ line: String,
        remainingPercent: Int
    ) -> String {
        let percent = "\(remainingPercent)%"
        guard let percentRange = line.range(of: percent) else {
            return line
        }
        let window = line[..<percentRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let date = line[percentRange.upperBound...]
            .trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines.union(
                    CharacterSet(charactersIn: "·")
                )
            )
        return "\(window)\t\(percent)\t· \(date)"
    }

    private static func applyPercentStyle(
        to result: NSMutableAttributedString,
        label: String,
        remainingPercent: Int,
        searchStart: String.Index
    ) {
        let target = "\(remainingPercent)%"
        var searchRange = NSRange(
            searchStart..<label.endIndex,
            in: label
        )
        while searchRange.location != NSNotFound,
              searchRange.location < result.length,
              let range = label.range(
                  of: target,
                  options: [],
                  range: Range(searchRange, in: label)
              )
        {
            let nsRange = NSRange(range, in: label)
            result.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: QuotaColorScale.components(
                        remainingPercent: remainingPercent
                    ).appKitColor
                ],
                range: nsRange
            )
            let nextLocation = nsRange.location + nsRange.length
            searchRange = NSRange(
                location: nextLocation,
                length: max(0, result.length - nextLocation)
            )
        }
    }

}

@MainActor
extension OverlayPanel {
    private func startHoverTimerIfNeeded() {
        guard hoverTimer == nil else {
            return
        }
        let timer = Timer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(pollHover),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    @objc
    private func pollHover() {
        guard
            isIndicatorVisible,
            latestDetail != nil
        else {
            detailPanel.hide()
            return
        }
        let point = NSEvent.mouseLocation
        let overIndicator = panel.frame.contains(point)
        let detailFrame = detailPanel.frame
        let overDetail = detailFrame?.contains(point) == true
        let overBridge = detailFrame.map {
            QuotaDetailLayout.hoverBridgeFrame(
                indicatorFrame: panel.frame,
                detailFrame: $0
            ).contains(point)
        } ?? false
        let overSettingsMenu = detailSettingsMenu.contains(point)
        if isHoveringIndicator != overIndicator {
            isHoveringIndicator = overIndicator
            updateControlAppearance()
        }
        detailInteraction.updatePointerInside(
            overIndicator || overDetail || overBridge || overSettingsMenu
        )
        updateDetailVisibility()
    }

    private func toggleDetailPin() {
        guard
            isIndicatorVisible,
            latestDetail != nil
        else {
            return
        }
        detailInteraction.togglePinned(
            pointerInside: panel.frame.contains(NSEvent.mouseLocation)
        )
        if detailInteraction.isPinned {
            installPinnedDetailOutsideMonitors()
        } else {
            removePinnedDetailOutsideMonitors()
        }
        updateControlAppearance()
        updateDetailVisibility()
    }

    private func showPositionModePopover() {
        guard isIndicatorVisible else { return }
        detailInteraction.reset()
        removePinnedDetailOutsideMonitors()
        detailPanel.hide()
        positionModePopover.show(
            relativeTo: panel.frame,
            mode: placementMode,
            localization: QuotaLocalization(language: latestLanguage),
            theme: latestTheme
        ) { [weak self] mode in
            guard let self else { return }
            self.placementMode = mode
            self.onPlacementModeSelected?(mode, self.panel.frame)
        }
    }

    private func showDetailSettingsMenu(relativeTo settingsButtonFrame: CGRect) {
        guard isIndicatorVisible else { return }
        detailSettingsMenu.show(
            relativeTo: settingsButtonFrame,
            mode: placementMode,
            localization: QuotaLocalization(language: latestLanguage),
            theme: latestTheme,
            onPlacementModeSelected: { [weak self] mode in
                guard let self else { return }
                self.placementMode = mode
                self.onPlacementModeSelected?(mode, self.panel.frame)
            },
            onCheckForUpdates: { [weak self] in
                guard let self,
                      let releasesURL = URL(
                        string: "https://github.com/JaceHwang/codex-usage-sidebar/releases"
                      )
                else {
                    return
                }
                self.externalLinkActivator.activate(releasesURL)
            },
            onReload: { [weak self] in
                self?.detailSettingsMenu.hide()
                self?.onReloadRequested?()
            },
            onQuit: { [weak self] in
                self?.detailSettingsMenu.hide()
                self?.onQuitRequested?()
            }
        )
    }

    private func dragIndicator(by delta: CGPoint) {
        guard
            placementMode == .free,
            let dragOrigin
        else {
            return
        }
        let frame = CGRect(
            x: dragOrigin.x + delta.x,
            y: dragOrigin.y + delta.y,
            width: panel.frame.width,
            height: panel.frame.height
        )
        let resolvedFrame = onIndicatorDragged?(frame) ?? frame
        panel.setFrameOrigin(resolvedFrame.origin)
        positionModePopover.reposition(relativeTo: panel.frame)
        detailSettingsMenu.hide()
        updateDetailVisibility()
    }

    private func updateDetailVisibility() {
        if
            isIndicatorVisible,
            detailInteraction.shouldShowDetail(
                whilePositionModeMenuIsPresented: positionModePopover.isVisible
            ),
            let latestDetail
        {
            detailPanel.show(
                content: latestDetail,
                relativeTo: panel.frame,
                theme: latestTheme
            )
        } else {
            detailSettingsMenu.hide()
            detailPanel.hide()
        }
    }

    private func dismissDetailForExternalNavigation() {
        detailInteraction.reset()
        removePinnedDetailOutsideMonitors()
        isHoveringIndicator = false
        detailSettingsMenu.hide()
        detailPanel.hide()
        updateControlAppearance()
    }

    private func installPinnedDetailOutsideMonitors() {
        removePinnedDetailOutsideMonitors()
        pinnedDetailOutsideGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissPinnedDetailIfPointerIsOutside()
            }
        }
        pinnedDetailOutsideLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.dismissPinnedDetailIfPointerIsOutside()
            }
            return event
        }
    }

    private func removePinnedDetailOutsideMonitors() {
        if let pinnedDetailOutsideGlobalMonitor {
            NSEvent.removeMonitor(pinnedDetailOutsideGlobalMonitor)
        }
        if let pinnedDetailOutsideLocalMonitor {
            NSEvent.removeMonitor(pinnedDetailOutsideLocalMonitor)
        }
        pinnedDetailOutsideGlobalMonitor = nil
        pinnedDetailOutsideLocalMonitor = nil
    }

    private func dismissPinnedDetailIfPointerIsOutside() {
        guard detailInteraction.isPinned else {
            removePinnedDetailOutsideMonitors()
            return
        }
        let pointer = NSEvent.mouseLocation
        let isInsideIndicator = panel.frame.contains(pointer)
        let isInsideDetail = detailPanel.frame?.contains(pointer) == true
        let isInsideSettingsMenu = detailSettingsMenu.contains(pointer)
        guard !isInsideIndicator, !isInsideDetail, !isInsideSettingsMenu else {
            return
        }
        detailInteraction.dismissForOutsideInteraction()
        removePinnedDetailOutsideMonitors()
        isHoveringIndicator = false
        detailSettingsMenu.hide()
        detailPanel.hide()
        updateControlAppearance()
    }

    private func updateControlAppearance() {
        let appearance = latestTheme.appKitAppearance
        appearance.performAsCurrentDrawingAppearance {
            switch OverlaySurfacePolicy.treatment(
                isIndicatorHovered: isHoveringIndicator ||
                    detailInteraction.isPinned
            ) {
            case .hostBackground:
                pillView.layer?.backgroundColor = NSColor.clear.cgColor
            case .quotaHover:
                pillView.layer?.backgroundColor = NSColor.labelColor
                    .withAlphaComponent(0.07)
                    .cgColor
            }
        }
    }
}
