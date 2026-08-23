#!/usr/bin/env python3
"""Build the fail-closed v0.3.3 Windows payload manifest."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from v033_release_profiles import FORMAL

VERSION = "0.3.3"
OFFICIAL_CODEX_RELEASE_PREFIX = "https://github.com/openai/codex/releases/download/"
REQUIRED_FILES = {
    "CodexUsageSidebar.Windows.exe", "CodexUsageSidebar.Control.exe", "codex.exe",
    "selectors.json", "windows-validation.json", "compatibility-update.json",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def payload_files(root: Path) -> dict[str, str]:
    entries = sorted(root.rglob("*"))
    links = [path.relative_to(root).as_posix() for path in entries if path.is_symlink()]
    if links:
        raise SystemExit("Windows v0.3.3 release payload cannot contain links: " + ", ".join(links))
    files = {path.relative_to(root).as_posix(): sha256(path) for path in entries
             if path.is_file() and path.name != "windows-payload.json"}
    missing = sorted(REQUIRED_FILES.difference(files))
    if missing:
        raise SystemExit("missing required Windows v0.3.3 payload files: " + ", ".join(missing))
    return files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--payload-dir", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--architecture", choices=("x64",), required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--codex-source", required=True)
    parser.add_argument("--codex-sha256", required=True)
    parser.add_argument("--validation-evidence", required=True, type=Path)
    arguments = parser.parse_args()
    if arguments.payload_dir.is_symlink() or arguments.validation_evidence.is_symlink():
        raise SystemExit("Windows v0.3.3 payload and evidence paths cannot be links")
    root = arguments.payload_dir.resolve(strict=True)
    evidence = arguments.validation_evidence.resolve(strict=True)
    if arguments.version != VERSION:
        raise SystemExit("Windows v0.3.3 payload version mismatch")
    if not re.fullmatch(r"[0-9a-f]{40}", arguments.source_commit):
        raise SystemExit("source commit must be a lowercase 40-character Git object ID")
    if not arguments.codex_source.startswith(OFFICIAL_CODEX_RELEASE_PREFIX):
        raise SystemExit("Codex runtime source must be an official OpenAI Codex release URL")
    if not re.fullmatch(r"[0-9a-f]{64}", arguments.codex_sha256):
        raise SystemExit("Codex runtime SHA-256 must be lowercase hexadecimal")
    subprocess.run([sys.executable, str(Path(__file__).with_name("verify-windows-v033-validation.py")),
                    str(evidence), "--source-commit", arguments.source_commit], check=True)
    embedded_evidence = root / "windows-validation.json"
    if evidence != embedded_evidence:
        with tempfile.NamedTemporaryFile("wb", dir=root, prefix=".windows-validation-", delete=False) as temporary:
            with evidence.open("rb") as source:
                shutil.copyfileobj(source, temporary)
            temporary_path = Path(temporary.name)
        os.replace(temporary_path, embedded_evidence)
    files = payload_files(root)
    if files["codex.exe"] != arguments.codex_sha256:
        raise SystemExit("Codex runtime digest does not match the supplied provenance")
    compatibility = json.loads((root / "compatibility-update.json").read_text(encoding="utf-8"))
    if set(compatibility) != {"schemaVersion", "publicKey", "updateUri"} or compatibility.get("schemaVersion") != 1:
        raise SystemExit("Windows v0.3.3 compatibility configuration has an invalid shape")
    try:
        public_key = base64.b64decode(compatibility["publicKey"], validate=True)
        if len(public_key) != 91 or not public_key.startswith(bytes.fromhex("3059301306072a8648ce3d020106082a8648ce3d03010703420004")):
            raise ValueError
    except (KeyError, TypeError, ValueError):
        raise SystemExit("Windows v0.3.3 compatibility configuration public key is not P-256 SPKI")
    if not isinstance(compatibility.get("updateUri"), str) or not re.fullmatch(r"https://[^\s]+", compatibility["updateUri"]):
        raise SystemExit("Windows v0.3.3 compatibility configuration update URI is not HTTPS")
    manifest = {
        "schemaVersion": 1, "version": VERSION, "architecture": arguments.architecture,
        "sourceCommit": arguments.source_commit, "status": "release",
        "realDeviceValidated": FORMAL["realDeviceValidated"], "publishableInstaller": True,
        "codexRuntime": {"source": arguments.codex_source, "sha256": arguments.codex_sha256},
        "compatibilityUpdate": {"sha256": files["compatibility-update.json"]}, "files": files,
        "realDeviceValidation": {
            "sha256": files["windows-validation.json"],
            "windowsBuild": json.loads(embedded_evidence.read_text(encoding="utf-8"))["windowsBuild"],
            "codexFileBuild": json.loads(embedded_evidence.read_text(encoding="utf-8"))["codexFileBuild"],
            "completedAt": json.loads(embedded_evidence.read_text(encoding="utf-8"))["completedAt"],
            "caseCounts": {name: len(cases) for name, cases in json.loads(embedded_evidence.read_text(encoding="utf-8"))["cases"].items()},
        },
    }
    output = root / "windows-payload.json"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=root, prefix=".windows-payload-", delete=False) as temporary:
        json.dump(manifest, temporary, indent=2, sort_keys=True)
        temporary.write("\n")
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, output)


if __name__ == "__main__":
    main()
