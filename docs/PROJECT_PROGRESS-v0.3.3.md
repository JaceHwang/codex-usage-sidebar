# Codex Usage Sidebar v0.3.3 progress

## Objective

Implement the approved dual-quota reference UI on both platforms: show the 5-hour and 7-day windows
in the titlebar button and in the quota detail card, with independent percentages, gradient bars,
reset times, localized copy, and the existing token/account/Credits/Bank/GitHub content preserved.

## Scope

- Official app-server `primary` and optional `secondary` rate-limit decoding.
- Simplified Chinese, Traditional Chinese, and English formatting.
- macOS AppKit popup and two-line titlebar indicator.
- Windows .NET/WPF popup and two-line titlebar indicator.
- Backward-compatible single-window fallback when `secondary` is absent.
- Local v0.3.3 macOS arm64 installer scripts and current screenshots.

## Acceptance matrix

| Area | Evidence | Status |
| --- | --- | --- |
| Swift core/data/formatter/layout | 276 tests, 0 failures | Done |
| Native visual regression | 8 tests; 12 light/dark and language fixtures | Done |
| macOS popup | Independent 5-hour/7-day bars and table rows | Done |
| macOS titlebar | Two-line summary with colored percentages | Done |
| Windows core/formatter | Shared secondary-window contract and localized rows | Done in source; Windows runner required |
| Windows WPF | Dual bars, icons, account footer, GitHub link | Done in source; Windows runner required |
| macOS installer | v0.3.3 build/package/verify scripts | Pending local packaging |
| Windows installer/device matrix | Build, UIA, DPI, theme, lifecycle | Pending Windows 11 AMD64/x64 host |

## Verification constraints

The current host is macOS Apple Silicon and does not have the .NET SDK, WPF runtime, or Windows UI
Automation environment. Windows source checks therefore remain static until a Windows machine runs the
solution build and device matrix. No GitHub push is part of this local implementation phase.
