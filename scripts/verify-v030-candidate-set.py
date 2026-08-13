#!/usr/bin/env python3
"""Verify the exact downloaded v0.3.0 release candidate asset set."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import tempfile
from pathlib import Path


VERSION = "0.3.0"
REPOSITORY = "JaceHwang/codex-usage-sidebar"
BRANCH = "v0.3.0"
WORKFLOW = ".github/workflows/v030-release-candidates.yml"
WINDOWS_ASSET = "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe"
WINDOWS_CHECKSUM = "WINDOWS-V030-SHA256SUMS.txt"
WINDOWS_PROVENANCE = "WINDOWS-V030-PROVENANCE.final.json"
WINDOWS_ARTIFACT = "codex-usage-sidebar-v0.3.0-windows-x64-candidate"
MACOS_ASSET = "codex-usage-sidebar-v0.3.0-macos-arm64.dmg"
MACOS_CHECKSUM = "MACOS-V030-SHA256SUMS.txt"
MACOS_PROVENANCE = "MACOS-V030-PROVENANCE.final.json"
MACOS_ARTIFACT = "codex-usage-sidebar-v0.3.0-macos-arm64-candidate"
EXPECTED = {
    WINDOWS_ASSET,
    WINDOWS_CHECKSUM,
    WINDOWS_PROVENANCE,
    MACOS_ASSET,
    MACOS_CHECKSUM,
    MACOS_PROVENANCE,
}
COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
ARTIFACT_DIGEST_PATTERN = re.compile(r"sha256:[0-9a-f]{64}")
REPARSE_POINT = 0x400


def is_link_or_reparse(path: Path) -> bool:
    details = path.lstat()
    return stat.S_ISLNK(details.st_mode) or bool(
        getattr(details, "st_file_attributes", 0) & REPARSE_POINT
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def stream_sha256(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def read_checksum(path: Path, asset_name: str) -> str:
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeError as error:
        raise SystemExit(f"checksum file is not UTF-8: {path.name}") from error
    match = re.fullmatch(rf"([0-9a-f]{{64}})  {re.escape(asset_name)}\r?\n", content)
    require(match is not None, f"invalid one-line checksum file: {path.name}")
    return match.group(1)


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise SystemExit(f"invalid provenance JSON: {path.name}") from error
    require(isinstance(value, dict), f"provenance root must be an object: {path.name}")
    return value


def validate_final_identity(
    data: dict,
    *,
    label: str,
    artifact_name: str,
    validated_source: str,
    packaging_commit: str,
) -> None:
    ci = data.get("ci")
    artifact = data.get("artifactRecord")
    release = data.get("release")
    require(isinstance(ci, dict), f"{label} provenance lacks finalized ci block")
    require(
        isinstance(artifact, dict),
        f"{label} provenance lacks finalized artifactRecord block",
    )
    require(
        isinstance(release, dict),
        f"{label} provenance lacks finalized release block",
    )
    run_id = ci.get("runId")
    artifact_id = artifact.get("id")
    require(type(run_id) is int and run_id > 0, f"invalid {label} CI run ID")
    require(
        type(artifact_id) is int and artifact_id > 0,
        f"invalid {label} artifact ID",
    )
    expected_url = f"https://github.com/{REPOSITORY}/actions/runs/{run_id}"
    checks = (
        (ci.get("repository") == REPOSITORY, "CI repository"),
        (ci.get("branch") == BRANCH, "CI branch"),
        (ci.get("event") == "push", "CI event"),
        (ci.get("workflowPath") == WORKFLOW, "CI workflow path"),
        (ci.get("runUrl") == expected_url, "CI run URL"),
        (ci.get("sourceCommit") == packaging_commit, "CI packaging commit"),
        (
            ci.get("validatedSourceCommit") == validated_source,
            "CI validated source commit",
        ),
        (artifact.get("name") == artifact_name, "artifact name"),
        (
            isinstance(artifact.get("digest"), str)
            and ARTIFACT_DIGEST_PATTERN.fullmatch(artifact["digest"]) is not None,
            "artifact digest",
        ),
        (release.get("repository") == REPOSITORY, "release repository"),
        (release.get("tag") == BRANCH, "release tag"),
    )
    for condition, field in checks:
        require(condition, f"invalid {label} {field}")


def validate_windows(data: dict, digest: str, source: str, packaging: str) -> None:
    checks = (
        (data.get("schemaVersion") == 1, "schema"),
        (data.get("status") == "release-candidate", "status"),
        (data.get("version") == VERSION, "version"),
        (data.get("architecture") == "x64", "architecture"),
        (data.get("runtimeIdentifier") == "win-x64", "runtime identifier"),
        (data.get("sourceCommit") == source, "source commit"),
        (data.get("validatedSourceCommit") == source, "validated source commit"),
        (data.get("packagingCommit") == packaging, "packaging commit"),
        (data.get("artifact") == WINDOWS_ASSET, "asset name"),
        (data.get("sha256") == digest, "asset digest"),
        (data.get("authenticodeStatus") == "NotSigned", "Authenticode status"),
        (data.get("signerSubject") is None, "signer subject"),
        (data.get("realDeviceValidated") is True, "real-device validation"),
        (data.get("publishableInstaller") is True, "publishable flag"),
    )
    for condition, field in checks:
        require(condition, f"invalid Windows {field}")
    validate_final_identity(
        data,
        label="Windows",
        artifact_name=WINDOWS_ARTIFACT,
        validated_source=source,
        packaging_commit=packaging,
    )


def validate_macos(data: dict, digest: str, source: str, packaging: str) -> None:
    asset = data.get("asset")
    require(isinstance(asset, dict), "invalid macOS asset block")
    checks = (
        (data.get("schemaVersion") == 3, "schema"),
        (data.get("status") == "release-candidate", "status"),
        (data.get("version") == VERSION, "version"),
        (data.get("platform") == "macos", "platform"),
        (data.get("architecture") == "arm64", "architecture"),
        (data.get("sourceCommit") == source, "source commit"),
        (data.get("validatedSourceCommit") == source, "validated source commit"),
        (data.get("payloadCommit") == source, "payload commit"),
        (data.get("packagingCommit") == packaging, "packaging commit"),
        (asset.get("name") == MACOS_ASSET, "asset name"),
        (asset.get("sha256") == digest, "asset digest"),
        (data.get("notarized") is False, "notarization status"),
    )
    for condition, field in checks:
        require(condition, f"invalid macOS {field}")
    validate_final_identity(
        data,
        label="macOS",
        artifact_name=MACOS_ARTIFACT,
        validated_source=source,
        packaging_commit=packaging,
    )


def atomic_write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate_directory", type=Path)
    parser.add_argument("--validated-source", required=True)
    parser.add_argument("--packaging-commit", required=True)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()

    require(
        COMMIT_PATTERN.fullmatch(arguments.validated_source) is not None,
        "validated source must be a lowercase 40-character Git object ID",
    )
    require(
        COMMIT_PATTERN.fullmatch(arguments.packaging_commit) is not None,
        "packaging commit must be a lowercase 40-character Git object ID",
    )
    try:
        require(
            not is_link_or_reparse(arguments.candidate_directory),
            "candidate directory cannot be a link or reparse point",
        )
        root = arguments.candidate_directory.resolve(strict=True)
    except FileNotFoundError as error:
        raise SystemExit("candidate directory does not exist") from error
    require(root.is_dir(), "candidate path is not a directory")

    entries = list(root.iterdir())
    actual = {entry.name for entry in entries}
    require(
        actual == EXPECTED and len(entries) == len(EXPECTED),
        "candidate directory must contain exactly the six expected files",
    )
    for entry in entries:
        require(
            not is_link_or_reparse(entry),
            f"candidate entry cannot be a link or reparse point: {entry.name}",
        )
        require(
            entry.is_file(),
            f"candidate entry is not a regular file: {entry.name}",
        )

    windows_digest = stream_sha256(root / WINDOWS_ASSET)
    macos_digest = stream_sha256(root / MACOS_ASSET)
    require(
        read_checksum(root / WINDOWS_CHECKSUM, WINDOWS_ASSET) == windows_digest,
        "Windows checksum mismatch",
    )
    require(
        read_checksum(root / MACOS_CHECKSUM, MACOS_ASSET) == macos_digest,
        "macOS checksum mismatch",
    )
    validate_windows(
        read_json(root / WINDOWS_PROVENANCE),
        windows_digest,
        arguments.validated_source,
        arguments.packaging_commit,
    )
    validate_macos(
        read_json(root / MACOS_PROVENANCE),
        macos_digest,
        arguments.validated_source,
        arguments.packaging_commit,
    )

    windows = read_json(root / WINDOWS_PROVENANCE)
    macos = read_json(root / MACOS_PROVENANCE)
    require(
        windows["ci"]["runId"] == macos["ci"]["runId"],
        "platform provenance records belong to different CI runs",
    )
    output = arguments.output.resolve(strict=False)
    try:
        output.relative_to(root)
    except ValueError:
        pass
    else:
        raise SystemExit("summary output must be outside the candidate directory")

    summary = {
        "version": VERSION,
        "validatedSourceCommit": arguments.validated_source,
        "packagingCommit": arguments.packaging_commit,
        "assets": {
            WINDOWS_ASSET: windows_digest,
            MACOS_ASSET: macos_digest,
        },
    }
    atomic_write_json(arguments.output, summary)
    print(
        f"PASS: exact v{VERSION} six-asset candidate set "
        f"for {arguments.packaging_commit}"
    )


if __name__ == "__main__":
    main()
