#!/usr/bin/env python3
"""Verify a publishable Windows v0.3.2 payload and its real-device evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
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
EXPECTED_CASE_COUNTS = {
    "visual": 108,
    "geometry": 9,
    "interaction": 6,
    "lifecycle": 7,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-profile", choices=tuple(PROFILES), default="formal")
    parser.add_argument("payload_dir", type=Path)
    arguments = parser.parse_args()
    descriptor = profile(arguments.release_profile)
    if arguments.payload_dir.is_symlink():
        raise SystemExit("Windows release payload root cannot be a link")
    root = arguments.payload_dir.resolve(strict=True)
    linked = [path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_symlink()]
    if linked:
        raise SystemExit("Windows release payload cannot contain links: " + ", ".join(linked))
    manifest_path = root / "windows-payload.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    if manifest.get("schemaVersion") != 1:
        raise SystemExit("unsupported Windows release payload schema")
    if manifest.get("version") != VERSION or manifest.get("architecture") != "x64":
        raise SystemExit("Windows release payload version or architecture mismatch")
    if (
        manifest.get("status") != "release"
        or manifest.get("realDeviceValidated") is not descriptor["realDeviceValidated"]
        or manifest.get("publishableInstaller") is not True
    ):
        raise SystemExit("Windows release payload is not explicitly validated and publishable")
    if arguments.release_profile == "formal":
        if "validationProfile" in manifest or "quickPrereleaseValidation" in manifest:
            raise SystemExit("formal Windows release payload cannot carry quick-prerelease metadata")
    elif manifest.get("validationProfile") != descriptor["releaseProfile"] \
            or "realDeviceValidation" in manifest:
        raise SystemExit("quick Windows release payload profile metadata is invalid")
    source_commit = manifest.get("sourceCommit", "")
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise SystemExit("invalid Windows release payload source commit")
    files = manifest.get("files")
    if not isinstance(files, dict) or not REQUIRED_FILES.issubset(files):
        raise SystemExit("Windows release payload file set is incomplete")

    actual_names = {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file() and path.name != manifest_path.name
    }
    if actual_names != set(files):
        raise SystemExit("Windows release payload contains undeclared or missing files")
    for relative, expected in files.items():
        if not isinstance(relative, str) or not isinstance(expected, str) \
                or not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise SystemExit("invalid Windows release payload file binding")
        target = (root / relative).resolve(strict=True)
        try:
            target.relative_to(root)
        except ValueError as error:
            raise SystemExit("Windows release payload file escapes its root") from error
        if sha256(target) != expected:
            raise SystemExit(f"Windows release payload digest mismatch: {relative}")

    runtime = manifest.get("codexRuntime", {})
    if runtime.get("sha256") != files["codex.exe"]:
        raise SystemExit("Codex runtime release provenance digest mismatch")
    if not str(runtime.get("source", "")).startswith(OFFICIAL_CODEX_RELEASE_PREFIX):
        raise SystemExit("Codex runtime release provenance source is invalid")
    evidence_path = root / "windows-validation.json"
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    validation_field = (
        "realDeviceValidation"
        if arguments.release_profile == "formal"
        else "quickPrereleaseValidation"
    )
    validation = manifest.get(validation_field, {})
    expected_validation_keys = {
        "sha256", "windowsBuild", "codexFileBuild", "completedAt",
        "caseCounts" if arguments.release_profile == "formal" else "smoke",
    }
    if not isinstance(validation, dict) or set(validation) != expected_validation_keys \
            or validation.get("sha256") != files["windows-validation.json"]:
        raise SystemExit("Windows validation evidence binding is invalid")
    if arguments.release_profile == "formal" \
            and validation.get("caseCounts") != EXPECTED_CASE_COUNTS:
        raise SystemExit("Windows real-device validation case counts are invalid")
    if arguments.release_profile == "quick-prerelease" \
            and validation.get("smoke") != evidence.get("smoke"):
        raise SystemExit("Windows quick-prerelease smoke summary does not match its evidence")
    if validation.get("windowsBuild") != evidence.get("windowsBuild") \
            or validation.get("codexFileBuild") != evidence.get("codexFileBuild") \
            or validation.get("completedAt") != evidence.get("completedAt"):
        raise SystemExit("Windows validation summary does not match its evidence")
    validator_name = (
        "verify-windows-v032-validation.py"
        if arguments.release_profile == "formal"
        else "verify-windows-v032-quick-prerelease.py"
    )
    validator = Path(__file__).with_name(validator_name)
    subprocess.run(
        [sys.executable, str(validator), str(evidence_path), "--source-commit", source_commit],
        check=True,
    )
    print(
        "PASS: Windows v0.3.2 release payload, evidence, digests, and provenance "
        f"({arguments.release_profile})"
    )


if __name__ == "__main__":
    main()
