#!/usr/bin/env python3
"""Verify all v0.3.3 Windows payload, compatibility, evidence, and provenance bindings."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from v033_release_profiles import FORMAL

VERSION = "0.3.3"
OFFICIAL_CODEX_RELEASE_PREFIX = "https://github.com/openai/codex/releases/download/"
REQUIRED_FILES = {"CodexUsageSidebar.Windows.exe", "CodexUsageSidebar.Control.exe", "codex.exe", "selectors.json", "windows-validation.json", "compatibility-update.json"}
EXPECTED_CASE_COUNTS = {"visual": 72, "geometry": 3, "interaction": 3, "lifecycle": 7}


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
        raise SystemExit("Windows v0.3.3 release payload root cannot be a link")
    root = arguments.payload_dir.resolve(strict=True)
    links = [path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_symlink()]
    if links:
        raise SystemExit("Windows v0.3.3 release payload cannot contain links: " + ", ".join(links))
    manifest_path = root / "windows-payload.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != 1 or manifest.get("version") != VERSION or manifest.get("architecture") != "x64":
        raise SystemExit("Windows v0.3.3 release payload version or architecture mismatch")
    if manifest.get("status") != "release" or manifest.get("realDeviceValidated") is not FORMAL["realDeviceValidated"] or manifest.get("publishableInstaller") is not True:
        raise SystemExit("Windows v0.3.3 release payload is not explicitly validated and publishable")
    source_commit = manifest.get("sourceCommit", "")
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise SystemExit("invalid Windows v0.3.3 release payload source commit")
    files = manifest.get("files")
    if not isinstance(files, dict) or not REQUIRED_FILES.issubset(files):
        raise SystemExit("Windows v0.3.3 release payload file set is incomplete")
    actual_names = {path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file() and path.name != manifest_path.name}
    if actual_names != set(files):
        raise SystemExit("Windows v0.3.3 release payload contains undeclared or missing files")
    for relative, expected in files.items():
        if not isinstance(relative, str) or not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise SystemExit("invalid Windows v0.3.3 release payload file binding")
        target = (root / relative).resolve(strict=True)
        try: target.relative_to(root)
        except ValueError as error: raise SystemExit("Windows v0.3.3 payload file escapes its root") from error
        if sha256(target) != expected: raise SystemExit(f"Windows v0.3.3 payload digest mismatch: {relative}")
    runtime = manifest.get("codexRuntime", {})
    if runtime.get("sha256") != files["codex.exe"] or not str(runtime.get("source", "")).startswith(OFFICIAL_CODEX_RELEASE_PREFIX):
        raise SystemExit("Codex runtime release provenance is invalid")
    compatibility = json.loads((root / "compatibility-update.json").read_text(encoding="utf-8"))
    if set(compatibility) != {"schemaVersion", "publicKey", "updateUri"} or compatibility.get("schemaVersion") != 1:
        raise SystemExit("Windows v0.3.3 compatibility configuration has an invalid shape")
    try:
        key = base64.b64decode(compatibility["publicKey"], validate=True)
        if len(key) != 91 or not key.startswith(bytes.fromhex("3059301306072a8648ce3d020106082a8648ce3d03010703420004")): raise ValueError
    except (KeyError, TypeError, ValueError):
        raise SystemExit("Windows v0.3.3 compatibility configuration public key is invalid")
    if not isinstance(compatibility.get("updateUri"), str) or not re.fullmatch(r"https://[^\s]+", compatibility["updateUri"]):
        raise SystemExit("Windows v0.3.3 compatibility configuration update URI is invalid")
    if manifest.get("compatibilityUpdate") != {"sha256": files["compatibility-update.json"]}:
        raise SystemExit("Windows v0.3.3 compatibility configuration is not bound to the payload manifest")
    evidence_path = root / "windows-validation.json"
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    validation = manifest.get("realDeviceValidation")
    if not isinstance(validation, dict) or validation.get("sha256") != files["windows-validation.json"] or validation.get("caseCounts") != EXPECTED_CASE_COUNTS:
        raise SystemExit("Windows v0.3.3 validation evidence binding is invalid")
    if any(validation.get(key) != evidence.get(key) for key in ("windowsBuild", "codexFileBuild", "completedAt")):
        raise SystemExit("Windows v0.3.3 validation summary does not match its evidence")
    subprocess.run([sys.executable, str(Path(__file__).with_name("verify-windows-v033-validation.py")), str(evidence_path), "--source-commit", source_commit], check=True)
    print("PASS: Windows v0.3.3 release payload, compatibility configuration, evidence, digests, and provenance")


if __name__ == "__main__":
    main()
