#!/usr/bin/env python3
"""Bind Windows v0.3.0 setup provenance to its exact GitHub Actions artifact."""

from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from pathlib import Path


import sys


sys.dont_write_bytecode = True
from v030_release_profiles import PROFILES, profile


EXPECTED_SETUP = "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe"
EXPECTED_ARTIFACT = "codex-usage-sidebar-v0.3.0-windows-x64-candidate"
EXPECTED_WORKFLOW = ".github/workflows/v030-release-candidates.yml"
EXPECTED_CODEX_SOURCE = (
    "https://github.com/openai/codex/releases/download/"
    "rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe"
)
EXPECTED_CODEX_SHA256 = (
    "935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d"
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-profile", choices=tuple(PROFILES), default="formal")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-repository", required=True)
    parser.add_argument("--run-repository", required=True)
    parser.add_argument("--run-id", required=True, type=int)
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--validated-source-sha", required=True)
    parser.add_argument("--workflow-path", required=True)
    parser.add_argument("--event", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--artifact-id", required=True, type=int)
    parser.add_argument("--artifact-name", required=True)
    parser.add_argument("--artifact-digest", required=True)
    parser.add_argument("--release-tag", required=True)
    args = parser.parse_args()
    descriptor = profile(args.release_profile)

    data = json.loads(args.input.read_text(encoding="utf-8"))
    runtime = data.get("codexRuntime", {})
    profile_matches = (
        "validationProfile" not in data
        if args.release_profile == "formal"
        else data.get("validationProfile") == descriptor["releaseProfile"]
    )
    checks = (
        (data.get("schemaVersion") == 1, "unsupported Windows provenance schema"),
        (data.get("status") == "release-candidate", "unexpected candidate status"),
        (data.get("version") == "0.3.0", "candidate version mismatch"),
        (data.get("architecture") == "x64", "candidate architecture mismatch"),
        (data.get("runtimeIdentifier") == "win-x64", "candidate runtime mismatch"),
        (data.get("artifact") == EXPECTED_SETUP, "setup asset mismatch"),
        (data.get("sourceCommit") == args.validated_source_sha, "source commit mismatch"),
        (data.get("validatedSourceCommit") == args.validated_source_sha, "validated source mismatch"),
        (data.get("packagingCommit") == args.head_sha, "packaging commit mismatch"),
        (profile_matches, "candidate validation profile mismatch"),
        (
            data.get("realDeviceValidated") is descriptor["realDeviceValidated"],
            "candidate validation status mismatch",
        ),
        (data.get("publishableInstaller") is True, "candidate is not publishable"),
        (runtime.get("source") == EXPECTED_CODEX_SOURCE, "Codex runtime source mismatch"),
        (runtime.get("sha256") == EXPECTED_CODEX_SHA256, "Codex runtime digest mismatch"),
        (args.expected_repository == args.run_repository, "CI run belongs to another repository"),
        (args.event == "push", "CI event must be push"),
        (args.branch == "v0.3.0", "CI branch must be v0.3.0"),
        (args.workflow_path == EXPECTED_WORKFLOW or args.workflow_path.startswith(EXPECTED_WORKFLOW + "@"), "workflow path mismatch"),
        (args.artifact_name == EXPECTED_ARTIFACT, "artifact name mismatch"),
        (args.release_tag == descriptor["tag"], "release tag mismatch"),
        (re.fullmatch(r"[0-9a-f]{40}", args.head_sha) is not None, "invalid packaging SHA"),
        (re.fullmatch(r"[0-9a-f]{40}", args.validated_source_sha) is not None, "invalid validated source SHA"),
        (re.fullmatch(r"sha256:[0-9a-f]{64}", args.artifact_digest) is not None, "invalid artifact digest"),
        (args.run_id > 0 and args.artifact_id > 0, "invalid run or artifact ID"),
    )
    for condition, message in checks:
        if not condition:
            raise SystemExit(message)
    for key in ("sha256", "payloadManifestSha256", "validationEvidenceSha256"):
        if re.fullmatch(r"[0-9a-f]{64}", str(data.get(key, ""))) is None:
            raise SystemExit(f"invalid Windows provenance digest: {key}")
    expected_url = f"https://github.com/{args.expected_repository}/actions/runs/{args.run_id}"
    if args.run_url != expected_url:
        raise SystemExit("CI run URL mismatch")
    if any(key in data for key in ("ci", "artifactRecord", "release")):
        raise SystemExit("Windows v0.3.0 provenance is already finalized")

    data["ci"] = {
        "branch": args.branch,
        "event": args.event,
        "repository": args.expected_repository,
        "runId": args.run_id,
        "runUrl": args.run_url,
        "sourceCommit": args.head_sha,
        "validatedSourceCommit": args.validated_source_sha,
        "workflowPath": args.workflow_path,
    }
    data["artifactRecord"] = {
        "digest": args.artifact_digest,
        "id": args.artifact_id,
        "name": args.artifact_name,
    }
    data["release"] = {"repository": args.expected_repository, "tag": args.release_tag}

    args.output.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=args.output.name + ".", dir=args.output.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, args.output)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


if __name__ == "__main__":
    main()
