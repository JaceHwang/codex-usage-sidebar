#!/usr/bin/env python3
import argparse
import json
import os
import re
import tempfile
from pathlib import Path


EXPECTED_ASSET = "codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
EXPECTED_ARTIFACT = "codex-usage-sidebar-installer-v0.2.3"
EXPECTED_RELEASE = "v0.2.3"
EXPECTED_WORKFLOW = ".github/workflows/ci.yml"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--expected-repository", required=True)
    parser.add_argument("--run-repository", required=True)
    parser.add_argument("--run-id", required=True, type=int)
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--workflow-path", required=True)
    parser.add_argument("--event", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--artifact-id", required=True, type=int)
    parser.add_argument("--artifact-name", required=True)
    parser.add_argument("--artifact-digest", required=True)
    parser.add_argument("--release-tag", required=True)
    parser.add_argument("--sdk-version", required=True)
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    args = parse_args()
    data = json.loads(Path(args.input).read_text(encoding="utf-8"))
    require(data.get("schemaVersion") == 2, "unsupported installer provenance schema")
    require(data.get("version") == "0.2.3", "installer provenance version mismatch")
    require(data.get("asset", {}).get("name") == EXPECTED_ASSET, "installer asset mismatch")
    require(data.get("installerSourceCommit") == args.head_sha, "CI source commit mismatch")
    require(re.fullmatch(r"[0-9a-f]{40}", args.head_sha) is not None, "invalid CI head SHA")
    require(args.expected_repository == args.run_repository, "CI run belongs to another repository")
    require(args.event == "push", "CI run is not a push")
    require(args.branch == "main", "CI run is not from main")
    require(
        args.workflow_path == EXPECTED_WORKFLOW
        or args.workflow_path.startswith(EXPECTED_WORKFLOW + "@"),
        "CI run used an unexpected workflow path",
    )
    require(args.run_id > 0, "invalid CI run ID")
    expected_run_url = (
        f"https://github.com/{args.expected_repository}/actions/runs/{args.run_id}"
    )
    require(args.run_url == expected_run_url, "CI run URL does not match repository and run ID")
    require(args.artifact_id > 0, "invalid artifact ID")
    require(args.artifact_name == EXPECTED_ARTIFACT, "unexpected artifact name")
    require(
        re.fullmatch(r"sha256:[0-9a-f]{64}", args.artifact_digest) is not None,
        "invalid artifact digest",
    )
    require(args.release_tag == EXPECTED_RELEASE, "unexpected release tag")
    require(data.get("sdk", {}).get("name") == "macosx", "unexpected SDK name")
    require(data.get("sdk", {}).get("version") == args.sdk_version, "SDK version mismatch")
    require(not any(key in data for key in ("ci", "artifact", "release")), "already promoted")

    data["ci"] = {
        "branch": args.branch,
        "event": args.event,
        "repository": args.expected_repository,
        "runId": args.run_id,
        "runUrl": args.run_url,
        "sourceCommit": args.head_sha,
        "workflowPath": args.workflow_path,
    }
    data["artifact"] = {
        "digest": args.artifact_digest,
        "id": args.artifact_id,
        "name": args.artifact_name,
    }
    data["release"] = {
        "repository": args.expected_repository,
        "tag": args.release_tag,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=output.name + ".", dir=output.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, output)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


if __name__ == "__main__":
    main()
