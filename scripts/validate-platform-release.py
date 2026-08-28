#!/usr/bin/env python3
"""Validate the source-controlled contract for a platform-specific release."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


SEMVER = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$")
REQUIRED_RELEASE_FIELDS = {
    "version",
    "tag",
    "title",
    "architecture",
    "minimumSystem",
    "codexCompatibility",
    "assets",
    "releaseNotes",
}
REQUIRED_ASSET_FIELDS = {"installer", "checksums", "provenance"}
PLATFORM_DISPLAY_NAMES = {"macos": "macOS", "windows": "Windows"}


def fail(message: str) -> None:
    raise SystemExit(f"release contract error: {message}")


def load_json(path: Path) -> dict[str, Any]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {path}: {error}")
    if not isinstance(document, dict):
        fail(f"{path} must contain a JSON object")
    return document


def validate_release(repo_root: Path, platform: str, phase: str, release: Any) -> None:
    if not isinstance(release, dict):
        fail(f"{phase}.{platform} must be an object")
    missing = REQUIRED_RELEASE_FIELDS - set(release)
    if missing:
        fail(f"{phase}.{platform} is missing {', '.join(sorted(missing))}")
    version = release["version"]
    if not isinstance(version, str) or not SEMVER.fullmatch(version):
        fail(f"{phase}.{platform}.version must be a semantic version")
    tag = release["tag"]
    if not isinstance(tag, str):
        fail(f"{phase}.{platform}.tag must be a string")
    if phase == "planned" and tag != f"{platform}-v{version}":
        fail(f"planned {platform} tag must be {platform}-v{version}")
    if phase == "published" and release.get("legacyTag") is not True and tag != f"{platform}-v{version}":
        fail(f"published {platform} tag must be {platform}-v{version} or declare legacyTag")
    expected_title = f"Codex Usage Sidebar {PLATFORM_DISPLAY_NAMES[platform]} v{version}"
    if release["title"] != expected_title:
        fail(f"{phase}.{platform}.title must be {expected_title!r}")
    assets = release["assets"]
    if not isinstance(assets, dict) or REQUIRED_ASSET_FIELDS - set(assets):
        fail(f"{phase}.{platform}.assets must include installer, checksums, and provenance")
    for name, value in assets.items():
        if not isinstance(value, str) or not value:
            fail(f"{phase}.{platform}.assets.{name} must be a non-empty string")
    if platform == "macos":
        expected_installer = f"codex-usage-sidebar-macos-arm64-v{version}.dmg"
        if phase == "published" and release.get("legacyTag") is True:
            expected_installer = f"codex-usage-sidebar-v{version}-macos-arm64.dmg"
        if assets["installer"] != expected_installer:
            fail(f"{phase}.macos installer must be {expected_installer}")
    if platform == "windows":
        expected_installer = f"codex-usage-sidebar-windows-x64-v{version}-setup.exe"
        if phase == "published" and release.get("legacyTag") is True:
            expected_installer = f"codex-usage-sidebar-v{version}-windows-x64-setup.exe"
        if assets["installer"] != expected_installer:
            fail(f"{phase}.windows installer must be {expected_installer}")
    release_notes = repo_root / release["releaseNotes"]
    if not release_notes.is_file():
        fail(f"release notes are missing: {release['releaseNotes']}")


def validate_candidate_payload(repo_root: Path, release: dict[str, Any]) -> None:
    manifest = load_json(repo_root / "plugins/codex-usage-sidebar/.codex-plugin/plugin.json")
    base_version = str(manifest.get("version", "")).split("+", 1)[0]
    if base_version != release["version"]:
        fail(
            "planned macOS version does not match the plugin manifest: "
            f"expected {release['version']}, found {base_version}"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--target", choices=("macos", "windows"), required=True)
    arguments = parser.parse_args()

    catalog_path = arguments.catalog.resolve()
    repo_root = catalog_path.parent.parent
    catalog = load_json(catalog_path)
    if catalog.get("schemaVersion") != 1:
        fail("unsupported catalog schemaVersion")
    if catalog.get("releasePolicy") != "independent-platform-patches":
        fail("releasePolicy must be independent-platform-patches")
    for phase in ("published", "planned"):
        releases = catalog.get(phase)
        if not isinstance(releases, dict):
            fail(f"catalog.{phase} must be an object")
        if arguments.target in releases:
            validate_release(repo_root, arguments.target, phase, releases[arguments.target])

    planned = catalog["planned"].get(arguments.target)
    if arguments.target == "macos" and isinstance(planned, dict):
        validate_candidate_payload(repo_root, planned)
    if planned is None and arguments.target not in catalog["published"]:
        fail(f"catalog has no {arguments.target} release")
    print(f"PASS: {PLATFORM_DISPLAY_NAMES[arguments.target]} release contract is valid")


if __name__ == "__main__":
    main()
