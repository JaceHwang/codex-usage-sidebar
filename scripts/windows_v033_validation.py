#!/usr/bin/env python3
"""Fixed, privacy-safe v0.3.3 Windows real-device evidence contract."""

from __future__ import annotations

from itertools import product


SCHEMA_VERSION = 1
VERSION = "0.3.3"
ARCHITECTURE = "x64"
MINIMUM_WINDOWS_BUILD = 22_000
VISUAL_LAYOUTS = ("wide", "narrow", "right-pane")
SCALES = (100, 125, 150, 200)
THEMES = ("light", "dark", "system")
LANGUAGES = ("en", "zh-CN")
GEOMETRY = ("restored", "maximized", "fullscreen")
INTERACTION = (
    "safe-dock-drag-snap",
    "safe-dock-lock-reset",
    "three-success-recovery",
)
LIFECYCLE = (
    "codex-restart-update",
    "sleep-resume",
    "app-server-recovery",
    "install-repair",
    "upgrade-retains-preferences",
    "uninstall",
    "package-provenance",
)


def expected_visual_keys() -> set[tuple[str, int, str, str]]:
    """Return every required visual matrix key without retaining device content."""
    return set(product(VISUAL_LAYOUTS, SCALES, THEMES, LANGUAGES))
