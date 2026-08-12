#!/usr/bin/env python3
"""Build a digest-bound Windows beta payload manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path


EXPECTED_VERSION = "0.3.0-beta.1"
OFFICIAL_CODEX_RELEASE_PREFIX = "https://github.com/openai/codex/releases/download/"
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


def payload_files(root: Path) -> dict[str, str]:
    entries = sorted(root.rglob("*"))
    linked = [path.relative_to(root).as_posix() for path in entries if path.is_symlink()]
    if linked:
        raise SystemExit("Windows payload cannot contain links: " + ", ".join(linked))
    files = {
        path.relative_to(root).as_posix(): sha256(path)
        for path in entries
        if path.is_file() and path.name != "windows-payload.json"
    }
    missing = sorted(REQUIRED_FILES.difference(files))
    if missing:
        raise SystemExit("missing required Windows payload files: " + ", ".join(missing))
    return files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--payload-dir", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--architecture", choices=("x64",), required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--codex-source", required=True)
    parser.add_argument("--codex-sha256", required=True)
    arguments = parser.parse_args()

    if arguments.payload_dir.is_symlink():
        raise SystemExit("Windows payload root cannot be a link")
    root = arguments.payload_dir.resolve(strict=True)
    if arguments.version != EXPECTED_VERSION:
        raise SystemExit(f"Windows payload version must be {EXPECTED_VERSION}")
    if not re.fullmatch(r"[0-9a-f]{40}", arguments.source_commit):
        raise SystemExit("source commit must be a lowercase 40-character Git object ID")
    if not arguments.codex_source.startswith(OFFICIAL_CODEX_RELEASE_PREFIX):
        raise SystemExit("Codex runtime source must be an official OpenAI Codex release URL")
    if not re.fullmatch(r"[0-9a-f]{64}", arguments.codex_sha256):
        raise SystemExit("Codex runtime SHA-256 must be lowercase hexadecimal")

    files = payload_files(root)
    if files["codex.exe"] != arguments.codex_sha256:
        raise SystemExit("Codex runtime digest does not match the supplied provenance")

    manifest = {
        "schemaVersion": 1,
        "version": arguments.version,
        "architecture": arguments.architecture,
        "sourceCommit": arguments.source_commit,
        "status": "device-test",
        "realDeviceValidated": False,
        "publishableInstaller": False,
        "codexRuntime": {
            "source": arguments.codex_source,
            "sha256": arguments.codex_sha256,
        },
        "files": files,
    }
    output = root / "windows-payload.json"
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=root, prefix=".windows-payload-", delete=False
    ) as temporary:
        json.dump(manifest, temporary, indent=2, sort_keys=True)
        temporary.write("\n")
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, output)


if __name__ == "__main__":
    main()
