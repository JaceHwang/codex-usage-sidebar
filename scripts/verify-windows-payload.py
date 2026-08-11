#!/usr/bin/env python3
"""Verify every binding in a Windows beta payload manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


EXPECTED_VERSION = "0.3.0-beta.1"
REQUIRED_FILES = {
    "CodexUsageSidebar.Windows.exe",
    "CodexUsageSidebar.Control.exe",
    "codex.exe",
    "selectors.json",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("payload_dir", type=Path)
    arguments = parser.parse_args()
    if arguments.payload_dir.is_symlink():
        raise SystemExit("Windows payload root cannot be a link")
    root = arguments.payload_dir.resolve(strict=True)
    linked = [path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_symlink()]
    if linked:
        raise SystemExit("Windows payload cannot contain links: " + ", ".join(linked))
    manifest_path = root / "windows-payload.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    if manifest.get("schemaVersion") != 1:
        raise SystemExit("unsupported Windows payload schema")
    if manifest.get("version") != EXPECTED_VERSION or manifest.get("architecture") != "x64":
        raise SystemExit("Windows payload version or architecture mismatch")
    if not re.fullmatch(r"[0-9a-f]{40}", manifest.get("sourceCommit", "")):
        raise SystemExit("invalid Windows payload source commit")
    files = manifest.get("files")
    if not isinstance(files, dict) or not REQUIRED_FILES.issubset(files):
        raise SystemExit("Windows payload file set is incomplete")

    actual_names = {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file() and path.name != manifest_path.name
    }
    if actual_names != set(files):
        raise SystemExit("Windows payload contains undeclared or missing files")
    for relative, expected in files.items():
        if not isinstance(relative, str) or not isinstance(expected, str):
            raise SystemExit("invalid Windows payload file binding")
        target = (root / relative).resolve(strict=True)
        try:
            target.relative_to(root)
        except ValueError as error:
            raise SystemExit("Windows payload file escapes its root") from error
        if sha256(target) != expected:
            raise SystemExit(f"Windows payload digest mismatch: {relative}")
    runtime = manifest.get("codexRuntime", {})
    if runtime.get("sha256") != files["codex.exe"]:
        raise SystemExit("Codex runtime provenance digest mismatch")
    if not str(runtime.get("source", "")).startswith("https://"):
        raise SystemExit("Codex runtime provenance source is invalid")

    print("PASS: Windows payload manifest, digests, version, architecture, and provenance")


if __name__ == "__main__":
    main()
