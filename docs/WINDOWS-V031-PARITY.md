# Windows v0.3.1 parity notes

The Windows implementation now follows the same visible quota-card contract as the current macOS
card. It uses the official Codex app-server over stdio and keeps the Codex application package
read-only.

## Shared visible behavior

- live remaining percentage and reset countdown with the shared red/orange/green palette;
- plan, quota period, Credits, all Bank reset entries, expiry/status text, and freshness;
- seven daily Token usage buckets plus the current-period total;
- Simplified Chinese, Traditional Chinese, English, and the same unsupported-locale fallback;
- account display name/email fallback and optional avatar URL from `account/read`;
- theme-aware quota icon, synchronized `v0.3.1` badge, compact native typography, and a
  borderless GitHub footer button;
- hover-to-show and click-to-pin interaction without activating or stealing focus from Codex.

## Intentional difference

The Tibo X information row is intentionally not rendered on Windows. The GitHub footer entry is
shared. No browser scraping, OAuth-cookie access, X API request, or prediction logic is used.

## Compatibility and degradation

There is no fixed minimum Codex file version. The host selector accepts a changed Codex build when
its title bar still exposes a safe semantic UI Automation structure. If `account/usage/read` or
`account/read` is missing, rejected, delayed, or malformed, the quota card remains visible: Token
usage becomes an unavailable seven-slot chart and account text falls back to a localized label.
Rate-limit data remains the required source for the percentage and reset rows.

## Local verification

From the repository root on macOS or Windows with .NET 8:

```text
dotnet restore plugins/codex-usage-sidebar/windows/CodexUsageSidebar.Windows.sln
dotnet build plugins/codex-usage-sidebar/windows/CodexUsageSidebar.Windows.sln --no-restore
dotnet test plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Core.Tests/CodexUsageSidebar.Core.Tests.csproj --no-restore
```

The final installer is intentionally a Windows-device gate. Build, signing/provenance, install,
repair, upgrade, uninstall, DPI, theme, pane-collision, and Codex lifecycle checks must run on a
Windows 11 AMD64/x64 machine before publishing `codex-usage-sidebar-v0.3.1-windows-x64-setup.exe`.
