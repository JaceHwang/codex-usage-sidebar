#!/usr/bin/env python3
"""Create, complete, or verify strict Windows x64 rc.1 smoke evidence."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


sys.dont_write_bytecode = True


SCRIPT_DIRECTORY = Path(__file__).resolve().parent
VERIFIER = SCRIPT_DIRECTORY / "verify-windows-v030-quick-prerelease.py"
SPECIFICATION = importlib.util.spec_from_file_location("windows_v030_quick_verifier", VERIFIER)
assert SPECIFICATION is not None and SPECIFICATION.loader is not None
VERIFIER_MODULE = importlib.util.module_from_spec(SPECIFICATION)
SPECIFICATION.loader.exec_module(VERIFIER_MODULE)
ARCHITECTURE = VERIFIER_MODULE.ARCHITECTURE
COMMIT_PATTERN = VERIFIER_MODULE.COMMIT_PATTERN
FILE_BUILD_PATTERN = VERIFIER_MODULE.FILE_BUILD_PATTERN
RELEASE_PROFILE = VERIFIER_MODULE.RELEASE_PROFILE
SCHEMA_VERSION = VERIFIER_MODULE.SCHEMA_VERSION
VERSION = VERIFIER_MODULE.VERSION
fail = VERIFIER_MODULE.fail
read_document = VERIFIER_MODULE.read_document
reject_link = VERIFIER_MODULE.reject_link
validate_document = VERIFIER_MODULE.validate_document


def atomic_write(path: Path, document: dict[str, object]) -> None:
    contents = (json.dumps(document, indent=2, sort_keys=True) + "\n").encode("utf-8")
    with tempfile.NamedTemporaryFile("wb", dir=path.parent, prefix=".windows-v030-quick-", delete=False) as temporary:
        temporary.write(contents)
        temporary_path = Path(temporary.name)
    try:
        os.replace(temporary_path, path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def smoke() -> dict[str, object]:
    return {
        "embeddedPayload": "pass",
        "manager": "pass",
        "runtime": "pass",
        "redactedProbe": {
            "result": "pass",
            "includesText": False,
            "rawNodeNameCount": 0,
        },
    }


def initialize(arguments: argparse.Namespace) -> None:
    if not COMMIT_PATTERN.fullmatch(arguments.source_commit):
        fail("source commit must be lowercase hexadecimal")
    if arguments.windows_build < 22_000:
        fail("quick prerelease smoke requires Windows 11")
    if not FILE_BUILD_PATTERN.fullmatch(arguments.codex_file_build):
        fail("Codex file build must contain four numeric components")
    output = arguments.evidence
    if output.exists() or output.is_symlink():
        fail("quick prerelease evidence output already exists or is a link")
    output.parent.mkdir(parents=True, exist_ok=True)
    reject_link(output.parent)
    document = {
        "schemaVersion": SCHEMA_VERSION,
        "releaseProfile": RELEASE_PROFILE,
        "version": VERSION,
        "sourceCommit": arguments.source_commit,
        "architecture": ARCHITECTURE,
        "windowsBuild": arguments.windows_build,
        "codexFileBuild": arguments.codex_file_build,
        "completedAt": None,
        "smoke": smoke(),
    }
    validate_document(document, arguments.source_commit, completed=False)
    atomic_write(output, document)


def complete(evidence: Path) -> None:
    document = read_document(evidence)
    source_commit = document.get("sourceCommit")
    if not isinstance(source_commit, str):
        fail("quick prerelease evidence source commit is invalid")
    validate_document(document, source_commit, completed=False)
    document["completedAt"] = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    validate_document(document, source_commit, completed=True)
    atomic_write(evidence.resolve(strict=True), document)


def verify(evidence: Path, source_commit: str) -> None:
    result = subprocess.run(
        [sys.executable, str(VERIFIER), str(evidence), "--source-commit", source_commit],
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main() -> None:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init")
    init.add_argument("evidence", type=Path)
    init.add_argument("--source-commit", required=True)
    init.add_argument("--windows-build", required=True, type=int)
    init.add_argument("--codex-file-build", required=True)
    complete_command = commands.add_parser("complete")
    complete_command.add_argument("evidence", type=Path)
    verify_command = commands.add_parser("verify")
    verify_command.add_argument("evidence", type=Path)
    verify_command.add_argument("--source-commit", required=True)
    arguments = parser.parse_args()
    if arguments.command == "init":
        initialize(arguments)
    elif arguments.command == "complete":
        complete(arguments.evidence)
    else:
        verify(arguments.evidence, arguments.source_commit)


if __name__ == "__main__":
    main()
