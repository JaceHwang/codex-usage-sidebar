#!/usr/bin/env python3
"""Require the public v0.3.0 Windows release documentation contract."""

import os
import shutil
import subprocess
from collections.abc import Callable
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


def select_windows_git_bash(
    candidates: tuple[Path, ...], exists: Callable[[Path], bool] = Path.is_file
) -> Path | None:
    """Choose only known Git Bash locations; a PATH bash could be the WSL launcher."""
    return next((candidate for candidate in candidates if exists(candidate)), None)


def windows_git_bash_candidates(environment: dict[str, str]) -> tuple[Path, ...]:
    roots = (
        Path("D:/app/Git"),
        Path("C:/Program Files/Git"),
        Path("C:/Program Files (x86)/Git"),
    )
    for name in ("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)"):
        value = environment.get(name)
        if value:
            roots += (Path(value) / "Git",)
    return tuple(dict.fromkeys(root / "bin/bash.exe" for root in roots))


def test_windows_bash_selection() -> None:
    candidates = windows_git_bash_candidates({"ProgramFiles": "C:/Program Files"})
    selected = select_windows_git_bash(
        candidates, lambda path: path == Path("C:/Program Files/Git/bin/bash.exe")
    )
    assert selected == Path("C:/Program Files/Git/bin/bash.exe")
    assert "C:/Windows/System32/bash.exe" not in {
        str(path) for path in windows_git_bash_candidates({})
    }


def run_v023_freeze_test() -> None:
    """Bind the public documentation contract to the established legacy guard."""
    if os.name == "nt":
        git_bash = select_windows_git_bash(windows_git_bash_candidates(dict(os.environ)))
        if git_bash is None:
            raise SystemExit(
                "cannot run the v0.2.3 freeze test: install Git Bash at D:/app/Git or Program Files"
            )
        root = ROOT.as_posix()
        root = f"/{ROOT.drive[0].lower()}{root[2:]}" if ROOT.drive else root
        command = f'cd "{root}" && tests/test-v023-publish-freeze.sh'
        result = subprocess.run([str(git_bash), "-lc", command], capture_output=True, text=True)
    else:
        bash = shutil.which("bash")
        if bash is None:
            raise SystemExit("cannot run the v0.2.3 freeze test: Bash was not found")
        result = subprocess.run(
            [bash, str(ROOT / "tests/test-v023-publish-freeze.sh")],
            capture_output=True,
            text=True,
        )
    if result.returncode != 0:
        raise SystemExit(
            "v0.2.3 freeze test failed while checking the release documentation contract:\n"
            f"{result.stdout}{result.stderr}"
        )


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

legacy_contract = "\n".join(
    text(relative)
    for relative in (
        "README.md",
        "README.zh-CN.md",
        "docs/INSTALL.md",
        "docs/TROUBLESHOOTING.md",
        "docs/releases/v0.3.0.md",
    )
)
assert "The macOS v0.2.3 application, its DMG, provenance, and release workflow are immutable history" in legacy_contract
run_v023_freeze_test()

for relative in ("README.md", "README.zh-CN.md"):
    assert "release candidate" not in text(relative)
assert "Windows setup publication remains blocked" not in text("README.md")

release = text("docs/releases/v0.3.0.md")
for marker in (WINDOWS_ASSET, MACOS_ASSET, "NotSigned", "151.0.7922.76"):
    assert marker in release

print("PASS: v0.3.0 public Windows release documentation contract is complete")
