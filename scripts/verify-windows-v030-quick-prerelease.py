#!/usr/bin/env python3
"""Verify strict, default-redacted Windows x64 rc.1 smoke evidence."""

from __future__ import annotations

import argparse
import json
import os
import re
import stat
import sys
from datetime import datetime
from pathlib import Path


sys.dont_write_bytecode = True


SCHEMA_VERSION = 1
VERSION = "0.3.0"
RELEASE_PROFILE = "quick-prerelease"
ARCHITECTURE = "x64"
TOP_LEVEL_KEYS = {
    "schemaVersion",
    "releaseProfile",
    "version",
    "sourceCommit",
    "architecture",
    "windowsBuild",
    "codexFileBuild",
    "completedAt",
    "smoke",
}
SMOKE_KEYS = {"embeddedPayload", "manager", "runtime", "redactedProbe"}
REDACTED_PROBE_KEYS = {"result", "includesText", "rawNodeNameCount"}
COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
FILE_BUILD_PATTERN = re.compile(r"[0-9]+(?:\.[0-9]+){3}")


def fail(message: str) -> None:
    raise SystemExit(message)


def is_windows_reparse_point(path: Path) -> bool:
    """Detect junctions and other Windows reparse points in addition to symlinks."""
    if os.name != "nt":
        return False
    attributes = getattr(path.lstat(), "st_file_attributes", 0)
    reparse_point = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    return bool(attributes & reparse_point)


def reject_link(path: Path) -> None:
    if path.is_symlink() or is_windows_reparse_point(path):
        fail("quick prerelease evidence cannot be a link")


def reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    value: dict[str, object] = {}
    for key, item in pairs:
        if key in value:
            fail("quick prerelease evidence cannot contain duplicate JSON keys")
        value[key] = item
    return value


def read_document(evidence: Path) -> dict[str, object]:
    reject_link(evidence)
    path = evidence.resolve(strict=True)
    try:
        document = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_keys)
    except json.JSONDecodeError as error:
        raise SystemExit("quick prerelease evidence is invalid JSON") from error
    if not isinstance(document, dict):
        fail("quick prerelease evidence has an invalid top-level shape")
    return document


def validate_document(document: dict[str, object], source_commit: str, *, completed: bool) -> None:
    if set(document) != TOP_LEVEL_KEYS:
        fail("quick prerelease evidence has an unexpected top-level shape")
    schema_version = document.get("schemaVersion")
    if not isinstance(schema_version, int) or isinstance(schema_version, bool) \
            or schema_version != SCHEMA_VERSION:
        fail("quick prerelease evidence schema is unsupported")
    if document.get("releaseProfile") != RELEASE_PROFILE or document.get("version") != VERSION:
        fail("quick prerelease evidence profile or version is invalid")
    evidence_commit = document.get("sourceCommit")
    if not isinstance(evidence_commit, str) or not COMMIT_PATTERN.fullmatch(evidence_commit):
        fail("quick prerelease evidence source commit is invalid")
    if evidence_commit != source_commit:
        fail("quick prerelease evidence source commit does not match")
    if document.get("architecture") != ARCHITECTURE:
        fail("quick prerelease evidence requires Windows AMD64/x64")
    windows_build = document.get("windowsBuild")
    if not isinstance(windows_build, int) or isinstance(windows_build, bool) or windows_build < 22_000:
        fail("quick prerelease evidence requires Windows 11")
    codex_file_build = document.get("codexFileBuild")
    if not isinstance(codex_file_build, str) or not FILE_BUILD_PATTERN.fullmatch(codex_file_build):
        fail("quick prerelease evidence Codex file build is invalid")
    completed_at = document.get("completedAt")
    if completed:
        if not isinstance(completed_at, str) or not re.fullmatch(
            r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", completed_at
        ):
            fail("quick prerelease evidence requires a UTC completion timestamp")
        try:
            datetime.fromisoformat(completed_at[:-1] + "+00:00")
        except ValueError as error:
            raise SystemExit("quick prerelease completion timestamp is invalid") from error
    elif completed_at is not None:
        fail("quick prerelease evidence cannot be completed during initialization")

    smoke = document.get("smoke")
    if not isinstance(smoke, dict) or set(smoke) != SMOKE_KEYS:
        fail("quick prerelease evidence smoke has an invalid shape")
    for name in ("embeddedPayload", "manager", "runtime"):
        if smoke.get(name) != "pass":
            fail(f"quick prerelease {name} smoke must pass")
    probe = smoke.get("redactedProbe")
    if not isinstance(probe, dict) or set(probe) != REDACTED_PROBE_KEYS:
        fail("quick prerelease redacted probe has an invalid shape")
    if probe.get("result") != "pass":
        fail("quick prerelease redacted probe must pass")
    if probe.get("includesText") is not False:
        fail("quick prerelease redacted probe must not include text")
    raw_node_name_count = probe.get("rawNodeNameCount")
    if not isinstance(raw_node_name_count, int) or isinstance(raw_node_name_count, bool) \
            or raw_node_name_count != 0:
        fail("quick prerelease redacted probe must not include raw node names")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--source-commit", required=True)
    arguments = parser.parse_args()
    if not COMMIT_PATTERN.fullmatch(arguments.source_commit):
        fail("expected source commit must be lowercase hexadecimal")
    validate_document(read_document(arguments.evidence), arguments.source_commit, completed=True)
    print("PASS: strict Windows x64 v0.3.0 rc.1 quick-prerelease smoke evidence")


if __name__ == "__main__":
    main()
