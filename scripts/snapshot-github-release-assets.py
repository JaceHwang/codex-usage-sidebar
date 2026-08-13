#!/usr/bin/env python3
"""Create and compare immutable GitHub release asset snapshots."""

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from urllib import parse as urllib_parse
from urllib import request as urllib_request


API_HOST = "api.github.com"
USER_AGENT = "codex-usage-sidebar-release-snapshot/1.0"
DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
REPOSITORY_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
TAG_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


class SnapshotError(Exception):
    pass


def validate_identity(repository, tag):
    if not REPOSITORY_RE.fullmatch(repository or ""):
        raise SnapshotError("invalid repository; expected OWNER/REPO")
    if not TAG_RE.fullmatch(tag or ""):
        raise SnapshotError("invalid tag")


def fetch_release(repository, tag):
    validate_identity(repository, tag)
    owner, repo = repository.split("/", 1)
    url = f"https://{API_HOST}/repos/{owner}/{repo}/releases/tags/{urllib_parse.quote(tag, safe='') }"
    request = urllib_request.Request(
        url,
        headers={"Accept": "application/vnd.github+json", "User-Agent": USER_AGENT},
        method="GET",
    )
    try:
        response = urllib_request.urlopen(request)
        with response:
            final_url = response.geturl()
            parsed = urllib_parse.urlparse(final_url)
            if parsed.scheme != "https" or parsed.hostname != API_HOST or parsed.port:
                raise SnapshotError("redirected response host is not api.github.com")
            return json.loads(response.read().decode("utf-8"))
    except SnapshotError:
        raise
    except Exception as exc:
        raise SnapshotError(f"GitHub release request failed: {exc}") from exc


def build_snapshot(repository, tag, release):
    validate_identity(repository, tag)
    if not isinstance(release, dict):
        raise SnapshotError("release JSON must be an object")
    release_id = release.get("id")
    api_tag = release.get("tag_name")
    if not isinstance(release_id, int) or isinstance(release_id, bool):
        raise SnapshotError("release id is missing or invalid")
    if api_tag != tag:
        raise SnapshotError("release tag does not match requested tag")
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise SnapshotError("release assets are missing or invalid")
    result_assets = []
    for asset in assets:
        if not isinstance(asset, dict):
            raise SnapshotError("release asset is invalid")
        digest = asset.get("digest")
        if not isinstance(digest, str) or not DIGEST_RE.fullmatch(digest):
            raise SnapshotError("each asset requires a lowercase sha256 digest")
        asset_id = asset.get("id")
        name = asset.get("name")
        size = asset.get("size")
        url = asset.get("browser_download_url")
        if not isinstance(asset_id, int) or isinstance(asset_id, bool) or not isinstance(name, str) or not isinstance(size, int) or isinstance(size, bool) or not isinstance(url, str):
            raise SnapshotError("asset identity fields are missing or invalid")
        result_assets.append({"id": asset_id, "name": name, "size": size, "digest": digest, "browserDownloadUrl": url})
    result_assets.sort(key=lambda item: item["name"])
    return {"repository": repository, "tag": tag, "releaseId": release_id, "assets": result_assets}


def load_release(input_json, repository, tag):
    if input_json:
        try:
            with open(input_json, "r", encoding="utf-8") as handle:
                return json.load(handle)
        except Exception as exc:
            raise SnapshotError(f"cannot read input JSON: {exc}") from exc
    return fetch_release(repository, tag)


def write_atomic(path, snapshot):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{target.name}.", suffix=".tmp", dir=str(target.parent), text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(snapshot, handle, sort_keys=False, indent=2, separators=(",", ": "))
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, target)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def parse_args(argv):
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    snap = sub.add_parser("snapshot")
    snap.add_argument("--repository", required=True)
    snap.add_argument("--tag", required=True)
    snap.add_argument("--output", required=True)
    snap.add_argument("--input-json")
    comp = sub.add_parser("compare")
    comp.add_argument("--baseline", required=True)
    comp.add_argument("--repository", required=True)
    comp.add_argument("--tag", required=True)
    comp.add_argument("--input-json")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        if args.command == "snapshot":
            snapshot = build_snapshot(args.repository, args.tag, load_release(args.input_json, args.repository, args.tag))
            write_atomic(args.output, snapshot)
            return 0
        with open(args.baseline, "r", encoding="utf-8") as handle:
            baseline = json.load(handle)
        current = build_snapshot(args.repository, args.tag, load_release(args.input_json, args.repository, args.tag))
        if baseline != current:
            raise SnapshotError("release asset snapshot changed")
        return 0
    except (SnapshotError, OSError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
