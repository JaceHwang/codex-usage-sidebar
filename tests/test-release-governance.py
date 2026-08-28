#!/usr/bin/env python3
"""Regression contract for the platform-aware release governance files."""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = REPO_ROOT / "releases" / "platform-release-catalog.json"
VALIDATOR = REPO_ROOT / "scripts" / "validate-platform-release.py"


class ReleaseGovernanceTests(unittest.TestCase):
    def test_catalog_declares_independent_platform_patch_releases(self) -> None:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

        self.assertEqual(1, catalog["schemaVersion"])
        self.assertEqual("independent-platform-patches", catalog["releasePolicy"])
        self.assertEqual("macos", catalog["activeCandidate"]["platform"])
        self.assertEqual("0.3.6", catalog["activeCandidate"]["version"])
        self.assertEqual("macos-v0.3.6", catalog["activeCandidate"]["tag"])
        self.assertEqual("0.3.6", catalog["planned"]["macos"]["version"])
        self.assertEqual("macos-v0.3.6", catalog["planned"]["macos"]["tag"])
        self.assertEqual(
            "codex-usage-sidebar-macos-arm64-v0.3.6.dmg",
            catalog["planned"]["macos"]["assets"]["installer"],
        )
        self.assertEqual("0.3.3", catalog["published"]["windows"]["version"])
        self.assertEqual("v0.3.3", catalog["published"]["windows"]["tag"])

    def test_release_validator_accepts_the_catalog_and_current_macos_manifest(self) -> None:
        completed = subprocess.run(
            [str(VALIDATOR), "--catalog", str(CATALOG_PATH), "--target", "macos"],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertIn("PASS: macOS release contract", completed.stdout)

    def test_governance_documents_describe_versions_releases_and_short_lived_branches(self) -> None:
        versioning = (REPO_ROOT / "VERSIONING.md").read_text(encoding="utf-8")
        releases = (REPO_ROOT / "docs" / "RELEASES.md").read_text(encoding="utf-8")
        project_guide = (REPO_ROOT / "docs" / "PROJECT_GOVERNANCE.md").read_text(encoding="utf-8")
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        readme_zh = (REPO_ROOT / "README.zh-CN.md").read_text(encoding="utf-8")

        for marker in (
            "MAJOR.MINOR.PATCH",
            "0.y.z",
            "macos-vX.Y.Z",
            "windows-vX.Y.Z",
            "release/macos-vX.Y.Z",
            "codex/hotfix-<platform>-vX.Y.Z",
        ):
            self.assertIn(marker, versioning)
        for marker in ("SHA256SUMS.txt", "PROVENANCE", "same verified commit"):
            self.assertIn(marker, releases)
        for marker in (
            "# Project Development Governance",
            "## Required workflow",
            "## Before pushing to GitHub",
            "## Before publishing a release",
            "CHANGELOG.md",
            "platform-release-catalog.json",
            "Do not rewrite published releases",
        ):
            self.assertIn(marker, project_guide)
        self.assertIn("PROJECT_GOVERNANCE.md", readme)
        self.assertIn("PROJECT_GOVERNANCE.md", readme_zh)

    def test_generic_macos_release_scripts_read_the_catalog_instead_of_a_hard_coded_version(self) -> None:
        for script_name in (
            "build-macos-platform-installer.sh",
            "package-macos-platform-installer.sh",
            "verify-macos-platform-installer-package.sh",
        ):
            script = REPO_ROOT / "scripts" / script_name
            self.assertTrue(script.is_file(), script_name)
            content = script.read_text(encoding="utf-8")
            self.assertIn("--catalog", content)
            self.assertIn("validate-platform-release.py", content)
            self.assertNotIn('version="0.3.6"', content)

    def test_macos_and_windows_ci_validate_the_platform_release_contract(self) -> None:
        macos_ci = (REPO_ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        windows_ci = (REPO_ROOT / ".github" / "workflows" / "windows-v031.yml").read_text(encoding="utf-8")

        self.assertIn("tests/test-release-governance.py", macos_ci)
        self.assertIn("--target macos", macos_ci)
        self.assertIn("releases/**", windows_ci)
        self.assertIn("--target windows", windows_ci)

    def test_macos_platform_release_workflow_builds_tagged_assets_from_the_catalog(self) -> None:
        workflow = (REPO_ROOT / ".github" / "workflows" / "macos-platform-release.yml").read_text(
            encoding="utf-8"
        )

        for marker in (
            '"macos-v*"',
            "build-macos-platform-installer.sh",
            "package-macos-platform-installer.sh",
            "verify-macos-platform-installer-package.sh",
            "name: codex-usage-sidebar-${{ inputs.ref || github.ref_name }}-macos-arm64",
            "path: .dist/${{ inputs.ref || github.ref_name }}/macos",
        ):
            self.assertIn(marker, workflow)


if __name__ == "__main__":
    unittest.main()
