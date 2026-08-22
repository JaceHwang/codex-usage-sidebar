#!/usr/bin/env python3
"""Build a publishable Windows v0.3.2 payload manifest after the full device gate."""

from __future__ import annotations

import argparse
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
from v032_release_profiles import PROFILES, profile


VERSION = "0.3.2"
OFFICIAL_CODEX_RELEASE_PREFIX = "https://github.com/openai/codex/releases/download/"
REQUIRED_FILES = {
    "CodexUsageSidebar.Windows.exe",
    "CodexUsageSidebar.Control.exe",
    "codex.exe",
    "selectors.json",
    "windows-validation.json",
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
        raise SystemExit("Windows release payload cannot contain links: " + ", ".join(linked))
    files = {
        path.relative_to(root).as_posix(): sha256(path)
        for path in entries
        if path.is_file() and path.name != "windows-payload.json"
    }
    missing = sorted(REQUIRED_FILES.difference(files))
    if missing:
        raise SystemExit("missing required Windows release payload files: " + ", ".join(missing))
    return files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-profile", choices=tuple(PROFILES), default="formal")
    parser.add_argument("--payload-dir", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--architecture", choices=("x64",), required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--codex-source", required=True)
    parser.add_argument("--codex-sha256", required=True)
    parser.add_argument("--validation-evidence", required=True, type=Path)
    arguments = parser.parse_args()
    descriptor = profile(arguments.release_profile)

    if arguments.payload_dir.is_symlink():
        raise SystemExit("Windows release payload root cannot be a link")
    root = arguments.payload_dir.resolve(strict=True)
    if arguments.validation_evidence.is_symlink():
        raise SystemExit("Windows validation evidence cannot be a link")
    evidence = arguments.validation_evidence.resolve(strict=True)
    if arguments.version != VERSION:
        raise SystemExit(f"Windows release payload version must be {VERSION}")
    if not re.fullmatch(r"[0-9a-f]{40}", arguments.source_commit):
        raise SystemExit("source commit must be a lowercase 40-character Git object ID")
    if not arguments.codex_source.startswith(OFFICIAL_CODEX_RELEASE_PREFIX):
        raise SystemExit("Codex runtime source must be an official OpenAI Codex release URL")
    if not re.fullmatch(r"[0-9a-f]{64}", arguments.codex_sha256):
        raise SystemExit("Codex runtime SHA-256 must be lowercase hexadecimal")

    validator_name = (
        "verify-windows-v032-validation.py"
        if arguments.release_profile == "formal"
        else "verify-windows-v032-quick-prerelease.py"
    )
    validator = Path(__file__).with_name(validator_name)
    subprocess.run(
        [sys.executable, str(validator), str(evidence), "--source-commit", arguments.source_commit],
        check=True,
    )
    evidence_document = json.loads(evidence.read_text(encoding="utf-8"))
    embedded_evidence = root / "windows-validation.json"
    if evidence != embedded_evidence:
        with tempfile.NamedTemporaryFile(
            "wb", dir=root, prefix=".windows-validation-", delete=False
        ) as temporary:
            with evidence.open("rb") as source:
                shutil.copyfileobj(source, temporary)
            temporary_path = Path(temporary.name)
        os.replace(temporary_path, embedded_evidence)

    files = payload_files(root)
    if files["codex.exe"] != arguments.codex_sha256:
        raise SystemExit("Codex runtime digest does not match the supplied provenance")
    manifest = {
        "schemaVersion": 1,
        "version": arguments.version,
        "architecture": arguments.architecture,
        "sourceCommit": arguments.source_commit,
        "status": "release",
        "realDeviceValidated": descriptor["realDeviceValidated"],
        "publishableInstaller": True,
        "codexRuntime": {
            "source": arguments.codex_source,
            "sha256": arguments.codex_sha256,
        },
        "files": files,
    }
    validation_summary = {
        "sha256": files["windows-validation.json"],
        "windowsBuild": evidence_document["windowsBuild"],
        "codexFileBuild": evidence_document["codexFileBuild"],
        "completedAt": evidence_document["completedAt"],
    }
    if arguments.release_profile == "formal":
        validation_cases = evidence_document["cases"]
        validation_summary["caseCounts"] = {
            name: len(cases) for name, cases in validation_cases.items()
        }
        manifest["realDeviceValidation"] = validation_summary
    else:
        manifest["validationProfile"] = descriptor["releaseProfile"]
        validation_summary["smoke"] = evidence_document["smoke"]
        manifest["quickPrereleaseValidation"] = validation_summary
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
