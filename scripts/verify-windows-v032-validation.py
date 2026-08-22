#!/usr/bin/env python3
"""Verify complete Windows v0.3.2 real-device evidence before release packaging."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True
from windows_v032_validation import (
    ARCHITECTURE,
    GEOMETRY_STATES,
    INTERACTION_STATES,
    LIFECYCLE_STATES,
    VERSION,
    expected_visual_keys,
)


TOP_LEVEL_KEYS = {
    "schemaVersion",
    "version",
    "sourceCommit",
    "architecture",
    "windowsBuild",
    "codexFileBuild",
    "completedAt",
    "cases",
}


def require_pass(case: dict[str, object], label: str) -> None:
    if case.get("result") != "pass":
        raise SystemExit(f"Windows validation case is not passed: {label}")


def require_named_cases(
    actual: object,
    expected: tuple[str, ...],
    group: str,
) -> None:
    if not isinstance(actual, list):
        raise SystemExit(f"Windows validation {group} cases must be a list")
    names: list[str] = []
    for case in actual:
        if not isinstance(case, dict) or set(case) != {"name", "result"}:
            raise SystemExit(f"Windows validation {group} case has an invalid shape")
        name = case.get("name")
        if not isinstance(name, str):
            raise SystemExit(f"Windows validation {group} case name is invalid")
        require_pass(case, f"{group}/{name}")
        names.append(name)
    if len(names) != len(set(names)) or set(names) != set(expected):
        raise SystemExit(f"Windows validation {group} cases are incomplete or duplicated")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--source-commit", required=True)
    arguments = parser.parse_args()

    if not re.fullmatch(r"[0-9a-f]{40}", arguments.source_commit):
        raise SystemExit("expected source commit must be lowercase hexadecimal")
    if arguments.evidence.is_symlink():
        raise SystemExit("Windows validation evidence cannot be a link")
    path = arguments.evidence.resolve(strict=True)
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit("Windows validation evidence is invalid JSON") from error
    if not isinstance(document, dict) or set(document) != TOP_LEVEL_KEYS:
        raise SystemExit("Windows validation evidence has an unexpected top-level shape")
    if document.get("schemaVersion") != 1:
        raise SystemExit("unsupported Windows validation evidence schema")
    if document.get("version") != VERSION or document.get("architecture") != ARCHITECTURE:
        raise SystemExit("Windows validation evidence version or architecture mismatch")
    if document.get("sourceCommit") != arguments.source_commit:
        raise SystemExit("Windows validation evidence source commit mismatch")
    windows_build = document.get("windowsBuild")
    if not isinstance(windows_build, int) or isinstance(windows_build, bool) or windows_build < 22_000:
        raise SystemExit("Windows validation evidence must come from Windows 11")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){3}", str(document.get("codexFileBuild", ""))):
        raise SystemExit("Windows validation evidence Codex file build is invalid")
    completed_at = document.get("completedAt")
    if not isinstance(completed_at, str) or not completed_at.endswith("Z"):
        raise SystemExit("completed Windows validation evidence requires a UTC timestamp")
    try:
        datetime.fromisoformat(completed_at[:-1] + "+00:00")
    except ValueError as error:
        raise SystemExit("Windows validation completion timestamp is invalid") from error

    cases = document.get("cases")
    if not isinstance(cases, dict) or set(cases) != {
        "visual", "geometry", "interaction", "lifecycle"
    }:
        raise SystemExit("Windows validation case groups are incomplete")

    visual = cases["visual"]
    if not isinstance(visual, list):
        raise SystemExit("Windows visual validation cases must be a list")
    actual_visual: set[tuple[str, str, str, int]] = set()
    for case in visual:
        if not isinstance(case, dict) or set(case) != {
            "layout", "theme", "language", "scale", "result"
        }:
            raise SystemExit("Windows visual validation case has an invalid shape")
        key = (
            case.get("layout"),
            case.get("theme"),
            case.get("language"),
            case.get("scale"),
        )
        if not isinstance(key[0], str) or not isinstance(key[1], str) \
                or not isinstance(key[2], str) or not isinstance(key[3], int) \
                or isinstance(key[3], bool):
            raise SystemExit("Windows visual validation case values are invalid")
        require_pass(case, "visual/" + "/".join(map(str, key)))
        actual_visual.add(key)  # type: ignore[arg-type]
    expected_visual = expected_visual_keys()
    if len(visual) != len(actual_visual) or actual_visual != expected_visual:
        raise SystemExit("Windows visual validation matrix is incomplete or duplicated")

    geometry = cases["geometry"]
    if not isinstance(geometry, list):
        raise SystemExit("Windows geometry validation cases must be a list")
    geometry_names: list[str] = []
    for case in geometry:
        if not isinstance(case, dict) or set(case) != {"state", "result"}:
            raise SystemExit("Windows geometry validation case has an invalid shape")
        state = case.get("state")
        if not isinstance(state, str):
            raise SystemExit("Windows geometry validation state is invalid")
        require_pass(case, f"geometry/{state}")
        geometry_names.append(state)
    if len(geometry_names) != len(set(geometry_names)) \
            or set(geometry_names) != set(GEOMETRY_STATES):
        raise SystemExit("Windows geometry validation cases are incomplete or duplicated")

    require_named_cases(cases["interaction"], INTERACTION_STATES, "interaction")
    require_named_cases(cases["lifecycle"], LIFECYCLE_STATES, "lifecycle")
    print("PASS: complete Windows v0.3.2 x64 real-device validation evidence")


if __name__ == "__main__":
    main()
