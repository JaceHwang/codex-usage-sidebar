import CoreGraphics
import Foundation

public struct SidebarToggleCandidate: Equatable, Sendable {
    public let frame: CGRect
    public let role: String
    public let description: String?

    public init(frame: CGRect, role: String, description: String?) {
        self.frame = frame
        self.role = role
        self.description = description
    }
}

public enum SidebarToggleResolver {
    public static func placement(
        candidates: [SidebarToggleCandidate],
        windowFrame: CGRect
    ) -> OverlayPlacement? {
        let visibleNavigationCount = candidates.filter {
            isVisibleSidebarNavigation($0, in: windowFrame)
        }.count
        if visibleNavigationCount >= 2 {
            return .sidebar
        }

        let matches = candidates.compactMap { candidate -> OverlayPlacement? in
            guard isLeftSidebarToggle(candidate, in: windowFrame) else {
                return nil
            }
            return placement(for: candidate.description)
        }

        var resolved: OverlayPlacement?
        for placement in matches {
            if let resolved, resolved != placement {
                return nil
            }
            resolved = placement
        }
        return resolved
    }

    private static func isVisibleSidebarNavigation(
        _ candidate: SidebarToggleCandidate,
        in windowFrame: CGRect
    ) -> Bool {
        guard candidate.role == "AXButton",
              (18...360).contains(candidate.frame.width),
              (18...64).contains(candidate.frame.height),
              let description = candidate.description?
                  .trimmingCharacters(in: .whitespacesAndNewlines)
                  .lowercased(),
              [
                  "搜索", "search",
                  "快速聊天", "quick chat",
                  "添加新项目", "add new project",
                  "新对话", "new chat",
              ].contains(description)
        else {
            return false
        }
        let relativeCenterX = candidate.frame.midX - windowFrame.minX
        let toolbarMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight
        return (30...340).contains(relativeCenterX)
            && candidate.frame.midY > windowFrame.minY + OverlayLayout.toolbarHeight
            && candidate.frame.midY < toolbarMinimumY - 4
    }

    private static func isLeftSidebarToggle(
        _ candidate: SidebarToggleCandidate,
        in windowFrame: CGRect
    ) -> Bool {
        guard candidate.role == "AXButton",
              (20...40).contains(candidate.frame.width),
              (20...40).contains(candidate.frame.height)
        else {
            return false
        }

        let relativeCenterX = candidate.frame.midX - windowFrame.minX
        let toolbarMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight
        return (90...150).contains(relativeCenterX)
            && candidate.frame.midY >= toolbarMinimumY
            && candidate.frame.midY <= windowFrame.maxY
    }

    private static func placement(for description: String?) -> OverlayPlacement? {
        let normalized = description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return switch normalized {
        case "隐藏边栏", "hide sidebar":
            .sidebar
        case "显示边栏", "show sidebar":
            .titlebar
        default:
            nil
        }
    }
}
