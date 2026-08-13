#!/usr/bin/env python3
"""Require the public v0.3.0 Windows release documentation contract."""

import os
import shutil
import subprocess
from collections.abc import Callable
from pathlib import Path, PurePosixPath, PureWindowsPath


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


def freeze_test_command(
    os_name: str,
    root: PureWindowsPath | PurePosixPath,
    environment: dict[str, str],
    exists: Callable[[Path], bool] = Path.is_file,
    which: Callable[[str], str | None] = shutil.which,
) -> tuple[str, ...]:
    if os_name == "nt":
        git_bash = select_windows_git_bash(
            windows_git_bash_candidates(environment), exists
        )
        if git_bash is None:
            raise RuntimeError(
                "cannot run the v0.2.3 freeze test: install Git Bash at D:/app/Git or Program Files"
            )
        root_posix = root.as_posix()
        root_posix = f"/{root.drive[0].lower()}{root_posix[2:]}" if root.drive else root_posix
        command = f'cd "{root_posix}" && tests/test-v023-publish-freeze.sh'
        return str(git_bash), "-lc", command

    bash = which("bash")
    if bash is None:
        raise RuntimeError("cannot run the v0.2.3 freeze test: Bash was not found")
    return bash, str(root / "tests/test-v023-publish-freeze.sh")


def test_windows_bash_selection() -> None:
    candidates = windows_git_bash_candidates(
        {
            "ProgramFiles": "E:/Program Files",
            "ProgramW6432": "F:/Program Files",
            "ProgramFiles(x86)": "G:/Program Files (x86)",
            "PATH": "C:/Windows/System32;C:/arbitrary/bin",
        }
    )
    assert candidates[:3] == (
        Path("D:/app/Git/bin/bash.exe"),
        Path("C:/Program Files/Git/bin/bash.exe"),
        Path("C:/Program Files (x86)/Git/bin/bash.exe"),
    )
    assert candidates[3:] == (
        Path("E:/Program Files/Git/bin/bash.exe"),
        Path("F:/Program Files/Git/bin/bash.exe"),
        Path("G:/Program Files (x86)/Git/bin/bash.exe"),
    )
    selected = select_windows_git_bash(
        candidates,
        lambda path: path
        in {
            Path("D:/app/Git/bin/bash.exe"),
            Path("C:/Program Files/Git/bin/bash.exe"),
        },
    )
    assert selected == Path("D:/app/Git/bin/bash.exe")
    assert select_windows_git_bash(
        candidates, lambda path: path == Path("C:/Windows/System32/bash.exe")
    ) is None

    windows_command = freeze_test_command(
        "nt",
        PureWindowsPath("C:/repo"),
        {},
        exists=lambda path: path == Path("D:/app/Git/bin/bash.exe"),
        which=lambda name: "C:/Windows/System32/bash.exe",
    )
    assert windows_command == (
        "D:\\app\\Git\\bin\\bash.exe",
        "-lc",
        'cd "/c/repo" && tests/test-v023-publish-freeze.sh',
    )

    try:
        freeze_test_command(
            "nt",
            PureWindowsPath("C:/repo"),
            {"PATH": "C:/Windows/System32;C:/arbitrary/bin"},
            exists=lambda path: False,
            which=lambda name: "C:/Windows/System32/bash.exe",
        )
    except RuntimeError as error:
        assert "install Git Bash" in str(error)
    else:
        raise AssertionError("Windows selection must fail when no known Git Bash exists")

    posix_command = freeze_test_command(
        "posix",
        PurePosixPath("/repo"),
        {},
        exists=lambda path: False,
        which=lambda name: "/usr/bin/bash" if name == "bash" else None,
    )
    assert posix_command == (
        "/usr/bin/bash",
        "/repo/tests/test-v023-publish-freeze.sh",
    )


def run_v023_freeze_test() -> None:
    """Bind the public documentation contract to the established legacy guard."""
    try:
        command = freeze_test_command(os.name, ROOT, dict(os.environ))
    except RuntimeError as error:
        raise SystemExit(str(error)) from error
    result = subprocess.run(command, capture_output=True, text=True)
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
test_windows_bash_selection()
run_v023_freeze_test()

for relative in ("README.md", "README.zh-CN.md"):
    assert "release candidate" not in text(relative)
assert "Windows setup publication remains blocked" not in text("README.md")

release = text("docs/releases/v0.3.0.md")
for marker in (WINDOWS_ASSET, MACOS_ASSET, "NotSigned", "151.0.7922.76"):
    assert marker in release

print("PASS: v0.3.0 public Windows release documentation contract is complete")
