import Foundation

public struct InstallerPresentationState: Equatable, Sendable {
    public var phase: InstallerPhase
    public var completedSteps: Set<InstallerStep>

    public static let initial = InstallerPresentationState(
        phase: .ready,
        completedSteps: []
    )

    public mutating func begin(_ step: InstallerStep) {
        phase = .running(step)
    }

    public mutating func waitForUser(_ step: InstallerStep) {
        phase = .waiting(step)
    }

    public mutating func accessibilitySettingsOpened() {
        guard phase == .waiting(.accessibility) else { return }
        phase = .waiting(.verify)
    }

    public mutating func complete(_ step: InstallerStep) {
        completedSteps.insert(step)
        phase = completedSteps.count == InstallerStep.allCases.count ? .succeeded : .ready
    }

    public mutating func fail(_ message: String) {
        phase = .failed(message)
    }
}

public struct InstallerCopy: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let version: String
    public let install: String
    public let repair: String
    public let uninstall: String
    public let authorize: String
    public let openAccessibility: String
    public let verify: String
    public let showDetails: String
    public let finderOpen: String
    public let readyMessage: String
    public let successMessage: String
    public let nextTaskMessage: String
    public let stepTitles: [String]

    public static let english = InstallerCopy(
        title: "Codex Usage Sidebar",
        subtitle: "Install live quota details in the Codex titlebar.",
        version: "Version 0.3.0 · macOS arm64",
        install: "Install",
        repair: "Repair",
        uninstall: "Uninstall",
        authorize: "Authorize Codex",
        openAccessibility: "Open Accessibility Settings",
        verify: "Verify Installation",
        showDetails: "Show details",
        finderOpen: "If macOS blocks this raw asset, right-click the app in Finder and choose Open.",
        readyMessage: "Ready to install the verified v0.3.0 payload.",
        successMessage: "Installed and verified. The quota control is running.",
        nextTaskMessage: "Start a new Codex task so Codex loads the plugin.",
        stepTitles: ["Check", "Install", "Codex login", "Accessibility", "Verify"]
    )

    public static let simplifiedChinese = InstallerCopy(
        title: "Codex 剩余额度",
        subtitle: "将实时额度信息安装到 Codex 标题栏。",
        version: "版本 0.3.0 · macOS arm64",
        install: "安装",
        repair: "修复",
        uninstall: "卸载",
        authorize: "授权 Codex",
        openAccessibility: "打开辅助功能设置",
        verify: "验证安装",
        showDetails: "显示详细信息",
        finderOpen: "如果 macOS 阻止打开，请在 Finder 中右键安装器并选择“打开”。",
        readyMessage: "已准备安装经过验证的 v0.3.0 载荷。",
        successMessage: "安装与验证成功，额度按钮正在运行。",
        nextTaskMessage: "请新建一个 Codex 任务，让 Codex 加载插件。",
        stepTitles: ["环境检查", "安装", "Codex 登录", "辅助功能", "验证"]
    )

    public static let traditionalChinese = InstallerCopy(
        title: "Codex 剩餘額度",
        subtitle: "將即時額度資訊安裝到 Codex 標題列。",
        version: "版本 0.3.0 · macOS arm64",
        install: "安裝",
        repair: "修復",
        uninstall: "解除安裝",
        authorize: "授權 Codex",
        openAccessibility: "開啟輔助使用設定",
        verify: "驗證安裝",
        showDetails: "顯示詳細資訊",
        finderOpen: "如果 macOS 阻止開啟，請在 Finder 中右鍵安裝程式並選擇「開啟」。",
        readyMessage: "已準備安裝經過驗證的 v0.3.0 載荷。",
        successMessage: "安裝與驗證成功，額度按鈕正在執行。",
        nextTaskMessage: "請建立一個 Codex 任務，讓 Codex 載入外掛程式。",
        stepTitles: ["環境檢查", "安裝", "Codex 登入", "輔助使用", "驗證"]
    )

    public static func forLanguageIdentifier(_ identifier: String) -> InstallerCopy {
        let normalized = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        if normalized.hasPrefix("zh") {
            if normalized.contains("hant") || normalized.contains("-tw") ||
                normalized.contains("-hk") || normalized.contains("-mo") {
                return .traditionalChinese
            }
            return .simplifiedChinese
        }
        return .english
    }
}
