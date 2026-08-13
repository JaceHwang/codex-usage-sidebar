#!/usr/bin/env python3
"""Require the public v0.3.0 Windows release documentation contract."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
WINDOWS_ASSET = "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe"
MACOS_ASSET = "codex-usage-sidebar-v0.3.0-macos-arm64.dmg"
WINDOWS_URL = (
    "https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.3.0/"
    "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe"
)


def text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


for relative in ("README.md", "README.zh-CN.md", "docs/INSTALL.md"):
    body = text(relative)
    assert WINDOWS_ASSET in body
    assert "Windows ARM64" in body
    assert "SHA-256" in body

english = text("README.md") + text("docs/INSTALL.md") + text("docs/TROUBLESHOOTING.md")
assert "Unknown publisher" in english
assert "More info" in english and "Run anyway" in english
chinese = text("README.zh-CN.md") + text("docs/INSTALL.md") + text("docs/TROUBLESHOOTING.md")
assert "未知发布者" in chinese
assert "更多信息" in chinese and "仍要运行" in chinese

combined = english + chinese
for forbidden in ("Turn off SmartScreen", "Disable Defender", "请关闭 SmartScreen", "请关闭 Defender"):
    assert forbidden not in combined

for relative in ("README.md", "README.zh-CN.md", "docs/INSTALL.md"):
    assert WINDOWS_URL in text(relative)

for relative in ("README.md", "README.zh-CN.md", "docs/INSTALL.md"):
    assert (
        "https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/"
        "codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
    ) in text(relative)

release = text("docs/releases/v0.3.0.md")
for marker in (WINDOWS_ASSET, MACOS_ASSET, "NotSigned", "151.0.7922.76"):
    assert marker in release

print("PASS: v0.3.0 public Windows release documentation contract is complete")
