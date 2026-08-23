#!/usr/bin/env python3
"""Fail closed unless v0.3.3 Windows evidence covers the exact passing matrix."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True
from windows_v033_validation import (
    ARCHITECTURE,
    GEOMETRY,
    INTERACTION,
    LIFECYCLE,
    MINIMUM_WINDOWS_BUILD,
    SCHEMA_VERSION,
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
CASE_GROUPS = {"visual", "geometry", "interaction", "lifecycle"}


def require_pass(case: dict[str, object], label: str) -> None:
    if case.get("result") != "pass":
        raise SystemExit(f"Windows v0.3.3 validation case is not passed: {label}")


def require_named_cases(actual: object, expected: tuple[str, ...], group: str) -> None:
    if not isinstance(actual, list):
        raise SystemExit(f"Windows v0.3.3 {group} cases must be a list")
    names: list[str] = []
    for case in actual:
        if not isinstance(case, dict) or set(case) != {"name", "result"}:
            raise SystemExit(f"Windows v0.3.3 {group} case has an invalid shape")
        name = case.get("name")
        if not isinstance(name, str):
            raise SystemExit(f"Windows v0.3.3 {group} case name is invalid")
        require_pass(case, f"{group}/{name}")
        names.append(name)
    if len(names) != len(set(names)) or set(names) != set(expected):
        raise SystemExit(f"Windows v0.3.3 {group} cases are incomplete or duplicated")


def load_document(path: Path) -> dict[str, object]:
    if path.is_symlink():
        raise SystemExit("Windows v0.3.3 validation evidence cannot be a link")
    try:
        document = json.loads(path.resolve(strict=True).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit("Windows v0.3.3 validation evidence is invalid JSON") from error
    if not isinstance(document, dict) or set(document) != TOP_LEVEL_KEYS:
        raise SystemExit("Windows v0.3.3 validation evidence has an unexpected top-level shape")
    return document


def validate_document(document: dict[str, object], source_commit: str) -> None:
    if document.get("schemaVersion") != SCHEMA_VERSION:
        raise SystemExit("unsupported Windows v0.3.3 validation evidence schema")
    if document.get("version") != VERSION or document.get("architecture") != ARCHITECTURE:
        raise SystemExit("Windows v0.3.3 validation evidence version or architecture mismatch")
    if document.get("sourceCommit") != source_commit:
        raise SystemExit("Windows v0.3.3 validation evidence source commit mismatch")
    windows_build = document.get("windowsBuild")
    if not isinstance(windows_build, int) or isinstance(windows_build, bool) or windows_build < MINIMUM_WINDOWS_BUILD:
        raise SystemExit("Windows v0.3.3 validation evidence must come from Windows 11")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){3}", str(document.get("codexFileBuild", ""))):
        raise SystemExit("Windows v0.3.3 validation evidence Codex file build is invalid")
    completed_at = document.get("completedAt")
    if not isinstance(completed_at, str) or not completed_at.endswith("Z"):
        raise SystemExit("completed Windows v0.3.3 validation evidence requires a UTC timestamp")
    try:
        datetime.fromisoformat(completed_at[:-1] + "+00:00")
    except ValueError as error:
        raise SystemExit("Windows v0.3.3 validation completion timestamp is invalid") from error

    cases = document.get("cases")
    if not isinstance(cases, dict) or set(cases) != CASE_GROUPS:
        raise SystemExit("Windows v0.3.3 validation case groups are incomplete")
    visual = cases["visual"]
    if not isinstance(visual, list):
        raise SystemExit("Windows v0.3.3 visual validation cases must be a list")
    actual_visual: set[tuple[str, int, str, str]] = set()
    for case in visual:
        if not isinstance(case, dict) or set(case) != {"layout", "scale", "theme", "language", "result"}:
            raise SystemExit("Windows v0.3.3 visual validation case has an invalid shape")
        key = (case.get("layout"), case.get("scale"), case.get("theme"), case.get("language"))
        if not isinstance(key[0], str) or not isinstance(key[1], int) or isinstance(key[1], bool) or not isinstance(key[2], str) or not isinstance(key[3], str):
            raise SystemExit("Windows v0.3.3 visual validation case values are invalid")
        require_pass(case, "visual/" + "/".join(map(str, key)))
        actual_visual.add(key)  # type: ignore[arg-type]
    expected_visual = expected_visual_keys()
    if len(visual) != len(actual_visual) or actual_visual != expected_visual:
        raise SystemExit("Windows v0.3.3 visual validation matrix is incomplete or duplicated")

    require_named_cases(cases["geometry"], GEOMETRY, "geometry")
    require_named_cases(cases["interaction"], INTERACTION, "interaction")
    require_named_cases(cases["lifecycle"], LIFECYCLE, "lifecycle")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--source-commit", required=True)
    arguments = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", arguments.source_commit):
        raise SystemExit("expected source commit must be lowercase hexadecimal")
    validate_document(load_document(arguments.evidence), arguments.source_commit)
    print("PASS: complete Windows v0.3.3 x64 real-device validation evidence")


if __name__ == "__main__":
    main()
