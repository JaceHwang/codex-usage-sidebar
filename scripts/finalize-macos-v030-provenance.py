#!/usr/bin/env python3
"""Bind a macOS v0.3.0 candidate provenance file to its exact GitHub Actions run."""

from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from pathlib import Path


EXPECTED_ASSET = "codex-usage-sidebar-v0.3.0-macos-arm64.dmg"
EXPECTED_ARTIFACT = "codex-usage-sidebar-v0.3.0-macos-arm64-candidate"
EXPECTED_RELEASE = "v0.3.0"
EXPECTED_WORKFLOW = ".github/workflows/v030-release-candidates.yml"


def main() -> None:
    parser = argparse.ArgumentParser()
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
    parser.add_argument("--sdk-version", required=True)
    args = parser.parse_args()

    data = json.loads(args.input.read_text(encoding="utf-8"))
    checks = (
        (data.get("schemaVersion") == 3, "unsupported macOS v0.3.0 provenance schema"),
        (data.get("status") == "release-candidate", "unexpected candidate status"),
        (data.get("version") == "0.3.0", "candidate version mismatch"),
        (data.get("architecture") == "arm64", "candidate architecture mismatch"),
        (data.get("asset", {}).get("name") == EXPECTED_ASSET, "candidate asset mismatch"),
        (data.get("sourceCommit") == args.validated_source_sha, "validated source commit mismatch"),
        (data.get("validatedSourceCommit") == args.validated_source_sha, "validated source binding mismatch"),
        (data.get("payloadCommit") == args.validated_source_sha, "payload commit mismatch"),
        (data.get("packagingCommit") == args.head_sha, "CI packaging commit mismatch"),
        (args.expected_repository == args.run_repository, "CI run belongs to another repository"),
        (args.event == "push", "CI event must be push"),
        (args.branch == "v0.3.0", "CI branch must be v0.3.0"),
        (args.workflow_path == EXPECTED_WORKFLOW or args.workflow_path.startswith(EXPECTED_WORKFLOW + "@"), "workflow path mismatch"),
        (args.artifact_name == EXPECTED_ARTIFACT, "artifact name mismatch"),
        (args.release_tag == EXPECTED_RELEASE, "release tag mismatch"),
        (data.get("sdk", {}).get("version") == args.sdk_version, "SDK version mismatch"),
        (re.fullmatch(r"[0-9a-f]{40}", args.head_sha) is not None, "invalid head SHA"),
        (re.fullmatch(r"[0-9a-f]{40}", args.validated_source_sha) is not None, "invalid validated source SHA"),
        (re.fullmatch(r"sha256:[0-9a-f]{64}", args.artifact_digest) is not None, "invalid artifact digest"),
        (args.run_id > 0 and args.artifact_id > 0, "invalid run or artifact ID"),
    )
    for condition, message in checks:
        if not condition:
            raise SystemExit(message)
    expected_url = f"https://github.com/{args.expected_repository}/actions/runs/{args.run_id}"
    if args.run_url != expected_url:
        raise SystemExit("CI run URL mismatch")
    if any(key in data for key in ("ci", "artifactRecord", "release")):
        raise SystemExit("macOS v0.3.0 provenance is already finalized")

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
