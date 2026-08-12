#!/usr/bin/env python3
"""Shared schema for the Windows v0.3.0 real-device release gate."""

from __future__ import annotations

from itertools import product


VERSION = "0.3.0"
ARCHITECTURE = "x64"
LAYOUTS = (
    "restored-collapsed",
    "right-wide",
    "left-right-expanded",
)
THEMES = ("light", "dark", "system")
LANGUAGES = ("zh-CN", "zh-TW", "en-US")
SCALES = (100, 125, 150, 200)
GEOMETRY_STATES = (
    "restored-collapsed",
    "left-expanded",
    "right-expanded",
    "right-wide",
    "left-right-expanded",
    "bottom-expanded",
    "narrow-window",
    "maximized",
    "fullscreen",
    "second-monitor",
)
INTERACTION_STATES = (
    "hover",
    "pin",
    "keyboard-focus",
    "no-activation",
    "resize-drag",
    "unknown-structure-fail-hidden",
)
LIFECYCLE_STATES = (
    "sleep-resume",
    "codex-restart",
    "codex-upgrade",
    "authorization",
    "install",
    "repair",
    "uninstall",
)


def pending_cases() -> dict[str, list[dict[str, object]]]:
    visual = [
        {
            "layout": layout,
            "theme": theme,
            "language": language,
            "scale": scale,
            "result": "pending",
        }
        for layout, theme, language, scale in product(
            LAYOUTS, THEMES, LANGUAGES, SCALES
        )
    ]
    return {
        "visual": visual,
        "geometry": [
            {"state": state, "result": "pending"} for state in GEOMETRY_STATES
        ],
        "interaction": [
            {"name": name, "result": "pending"} for name in INTERACTION_STATES
        ],
        "lifecycle": [
            {"name": name, "result": "pending"} for name in LIFECYCLE_STATES
        ],
    }


def expected_visual_keys() -> set[tuple[str, str, str, int]]:
    return set(product(LAYOUTS, THEMES, LANGUAGES, SCALES))
