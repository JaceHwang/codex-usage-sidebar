#!/usr/bin/env python3
"""Atomically record one Windows v0.3.0 real-device validation case."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

sys.dont_write_bytecode = True
SCRIPT_DIRECTORY = Path(__file__).resolve().parent
if str(SCRIPT_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIRECTORY))
from windows_v030_validation import (
    ARCHITECTURE,
    GEOMETRY_STATES,
    INTERACTION_STATES,
    LIFECYCLE_STATES,
    VERSION,
    expected_visual_keys,
)


def load_verifier_constants() -> set[str]:
    specification = importlib.util.spec_from_file_location(
        "windows_v030_verifier", SCRIPT_DIRECTORY / "verify-windows-v030-validation.py"
    )
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module.TOP_LEVEL_KEYS


TOP_LEVEL_KEYS = load_verifier_constants()


CASE_GROUPS = {"visual", "geometry", "interaction", "lifecycle"}
COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
FILE_BUILD_PATTERN = re.compile(r"[0-9]+(?:\.[0-9]+){3}")


def fail(message: str) -> None:
    raise SystemExit(message)


def read_document(path: Path) -> tuple[Path, bytes, dict[str, object]]:
    if path.is_symlink() or is_windows_reparse_point(path):
        fail("Windows validation evidence cannot be a link")
    resolved = path.resolve(strict=True)
    contents = resolved.read_bytes()
    try:
        document = json.loads(contents)
    except json.JSONDecodeError as error:
        raise SystemExit("Windows validation evidence is invalid JSON") from error
    if not isinstance(document, dict):
        fail("Windows validation evidence has an unexpected top-level shape")
    validate_document(document)
    return resolved, contents, document


def is_windows_reparse_point(path: Path) -> bool:
    """Reject Windows junctions and other reparse points, not only symlinks."""
    if os.name != "nt":
        return False
    attributes = getattr(path.lstat(), "st_file_attributes", 0)
    reparse_point = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    return bool(attributes & reparse_point)


def validate_document(document: dict[str, object]) -> None:
    if set(document) != TOP_LEVEL_KEYS:
        fail("Windows validation evidence has an unexpected top-level shape")
    if document.get("schemaVersion") != 1:
        fail("unsupported Windows validation evidence schema")
    if document.get("version") != VERSION or document.get("architecture") != ARCHITECTURE:
        fail("Windows validation evidence version or architecture mismatch")
    source_commit = document.get("sourceCommit")
    if not isinstance(source_commit, str) or not COMMIT_PATTERN.fullmatch(source_commit):
        fail("Windows validation evidence source commit is invalid")
    windows_build = document.get("windowsBuild")
    if not isinstance(windows_build, int) or isinstance(windows_build, bool) or windows_build < 22_000:
        fail("Windows validation evidence must come from Windows 11")
    if not isinstance(document.get("codexFileBuild"), str) or not FILE_BUILD_PATTERN.fullmatch(document["codexFileBuild"]):
        fail("Windows validation evidence Codex file build is invalid")
    if document.get("completedAt") is not None:
        fail("completed Windows validation evidence cannot be modified")
    cases = document.get("cases")
    if not isinstance(cases, dict) or set(cases) != CASE_GROUPS:
        fail("Windows validation case groups are incomplete")
    validate_visual(cases["visual"])
    validate_geometry(cases["geometry"])
    validate_named(cases["interaction"], INTERACTION_STATES, "interaction")
    validate_named(cases["lifecycle"], LIFECYCLE_STATES, "lifecycle")


def validate_result(case: dict[str, object], label: str) -> None:
    if case.get("result") not in {"pending", "pass"}:
        fail(f"Windows validation {label} result is invalid")


def validate_visual(actual: object) -> None:
    if not isinstance(actual, list):
        fail("Windows visual validation cases must be a list")
    keys: set[tuple[str, str, str, int]] = set()
    for case in actual:
        if not isinstance(case, dict) or set(case) != {"layout", "theme", "language", "scale", "result"}:
            fail("Windows visual validation case has an invalid shape")
        key = (case.get("layout"), case.get("theme"), case.get("language"), case.get("scale"))
        if not isinstance(key[0], str) or not isinstance(key[1], str) or not isinstance(key[2], str) or not isinstance(key[3], int) or isinstance(key[3], bool):
            fail("Windows visual validation case values are invalid")
        validate_result(case, "visual")
        keys.add(key)
    if len(actual) != len(keys) or keys != expected_visual_keys():
        fail("Windows visual validation matrix is incomplete or duplicated")


def validate_geometry(actual: object) -> None:
    if not isinstance(actual, list):
        fail("Windows geometry validation cases must be a list")
    names: list[str] = []
    for case in actual:
        if not isinstance(case, dict) or set(case) != {"state", "result"} or not isinstance(case.get("state"), str):
            fail("Windows geometry validation case has an invalid shape")
        validate_result(case, "geometry")
        names.append(case["state"])
    if len(names) != len(set(names)) or set(names) != set(GEOMETRY_STATES):
        fail("Windows geometry validation cases are incomplete or duplicated")


def validate_named(actual: object, expected: tuple[str, ...], group: str) -> None:
    if not isinstance(actual, list):
        fail(f"Windows validation {group} cases must be a list")
    names: list[str] = []
    for case in actual:
        if not isinstance(case, dict) or set(case) != {"name", "result"} or not isinstance(case.get("name"), str):
            fail(f"Windows validation {group} case has an invalid shape")
        validate_result(case, group)
        names.append(case["name"])
    if len(names) != len(set(names)) or set(names) != set(expected):
        fail(f"Windows validation {group} cases are incomplete or duplicated")


def atomic_write(path: Path, contents: bytes) -> None:
    with tempfile.NamedTemporaryFile("wb", dir=path.parent, prefix=".windows-v030-", delete=False) as temporary:
        temporary.write(contents)
        temporary_path = Path(temporary.name)
    try:
        os.replace(temporary_path, path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def write_document(path: Path, document: dict[str, object]) -> None:
    atomic_write(path, (json.dumps(document, indent=2, sort_keys=True) + "\n").encode("utf-8"))


def record_case(path: Path, group: str, predicate: object) -> None:
    resolved, _, document = read_document(path)
    cases = document["cases"]
    assert isinstance(cases, dict)
    matches = [case for case in cases[group] if predicate(case)]  # type: ignore[index, operator]
    if len(matches) != 1:
        fail("Windows validation case does not exist")
    selected = matches[0]
    if selected["result"] != "pending":
        fail("Windows validation case was already recorded")
    selected["result"] = "pass"
    write_document(resolved, document)


def verify_completed(path: Path, source_commit: str) -> bool:
    verifier = SCRIPT_DIRECTORY / "verify-windows-v030-validation.py"
    return subprocess.run(
        [sys.executable, str(verifier), str(path), "--source-commit", source_commit],
        check=False,
    ).returncode == 0


def complete(path: Path) -> None:
    resolved, original_contents, document = read_document(path)
    cases = document["cases"]
    assert isinstance(cases, dict)
    if any(case["result"] != "pass" for group in cases.values() for case in group):
        fail("Windows validation evidence has pending cases")
    document["completedAt"] = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    write_document(resolved, document)
    source_commit = document["sourceCommit"]
    assert isinstance(source_commit, str)
    try:
        verified = verify_completed(resolved, source_commit)
    except BaseException:
        atomic_write(resolved, original_contents)
        raise
    if not verified:
        atomic_write(resolved, original_contents)
        fail("Windows validation evidence failed final verification")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    subcommands = parser.add_subparsers(dest="command", required=True)
    visual = subcommands.add_parser("visual")
    visual.add_argument("--layout", required=True)
    visual.add_argument("--theme", required=True)
    visual.add_argument("--language", required=True)
    visual.add_argument("--scale", required=True, type=int)
    geometry = subcommands.add_parser("geometry")
    geometry.add_argument("--state", required=True)
    for name in ("interaction", "lifecycle"):
        command = subcommands.add_parser(name)
        command.add_argument("--name", required=True)
    subcommands.add_parser("complete")
    arguments = parser.parse_args()
    if arguments.command == "visual":
        record_case(arguments.evidence, "visual", lambda case: (case["layout"], case["theme"], case["language"], case["scale"]) == (arguments.layout, arguments.theme, arguments.language, arguments.scale))
    elif arguments.command == "geometry":
        record_case(arguments.evidence, "geometry", lambda case: case["state"] == arguments.state)
    elif arguments.command in {"interaction", "lifecycle"}:
        record_case(arguments.evidence, arguments.command, lambda case: case["name"] == arguments.name)
    else:
        complete(arguments.evidence)


if __name__ == "__main__":
    main()
