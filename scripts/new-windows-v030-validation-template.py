#!/usr/bin/env python3
"""Create a pending Windows v0.3.0 real-device validation template."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from windows_v030_validation import ARCHITECTURE, VERSION, pending_cases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--windows-build", required=True, type=int)
    parser.add_argument("--codex-file-build", required=True)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()

    if not re.fullmatch(r"[0-9a-f]{40}", arguments.source_commit):
        raise SystemExit("source commit must be a lowercase 40-character Git object ID")
    if arguments.windows_build < 22_000:
        raise SystemExit("Windows v0.3.0 validation requires Windows 11 build 22000 or newer")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){3}", arguments.codex_file_build):
        raise SystemExit("Codex file build must contain four numeric components")
    if arguments.output.is_symlink():
        raise SystemExit("validation evidence output cannot be a link")
    output = arguments.output.resolve()
    if output.exists():
        raise SystemExit("validation evidence output already exists")
    output.parent.mkdir(parents=True, exist_ok=True)

    document = {
        "schemaVersion": 1,
        "version": VERSION,
        "sourceCommit": arguments.source_commit,
        "architecture": ARCHITECTURE,
        "windowsBuild": arguments.windows_build,
        "codexFileBuild": arguments.codex_file_build,
        "completedAt": None,
        "cases": pending_cases(),
    }
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=output.parent, prefix=".windows-v030-", delete=False
    ) as temporary:
        json.dump(document, temporary, indent=2, sort_keys=True)
        temporary.write("\n")
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, output)


if __name__ == "__main__":
    main()
