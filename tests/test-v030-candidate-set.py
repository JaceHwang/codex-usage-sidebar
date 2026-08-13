#!/usr/bin/env python3
"""Behavior tests for the downloaded v0.3.0 six-asset verifier."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
VERIFIER = REPO_ROOT / "scripts" / "verify-v030-candidate-set.py"
SOURCE = "0123456789abcdef0123456789abcdef01234567"
PACKAGING = "fedcba9876543210fedcba9876543210fedcba98"
WINDOWS_ASSET = "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe"
WINDOWS_CHECKSUM = "WINDOWS-V030-SHA256SUMS.txt"
WINDOWS_PROVENANCE = "WINDOWS-V030-PROVENANCE.final.json"
WINDOWS_ARTIFACT = "codex-usage-sidebar-v0.3.0-windows-x64-candidate"
MACOS_ASSET = "codex-usage-sidebar-v0.3.0-macos-arm64.dmg"
MACOS_CHECKSUM = "MACOS-V030-SHA256SUMS.txt"
MACOS_PROVENANCE = "MACOS-V030-PROVENANCE.final.json"
MACOS_ARTIFACT = "codex-usage-sidebar-v0.3.0-macos-arm64-candidate"
REPOSITORY = "JaceHwang/codex-usage-sidebar"
WORKFLOW = ".github/workflows/v030-release-candidates.yml"

VERIFIER_SPEC = importlib.util.spec_from_file_location("v030_candidate_verifier", VERIFIER)
assert VERIFIER_SPEC is not None and VERIFIER_SPEC.loader is not None
VERIFIER_MODULE = importlib.util.module_from_spec(VERIFIER_SPEC)
VERIFIER_SPEC.loader.exec_module(VERIFIER_MODULE)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def finalized_identity(artifact_name: str, run_id: int, artifact_id: int) -> dict:
    return {
        "ci": {
            "branch": "v0.3.0",
            "event": "push",
            "repository": REPOSITORY,
            "runId": run_id,
            "runUrl": f"https://github.com/{REPOSITORY}/actions/runs/{run_id}",
            "sourceCommit": PACKAGING,
            "validatedSourceCommit": SOURCE,
            "workflowPath": WORKFLOW,
        },
        "artifactRecord": {
            "digest": "sha256:" + ("d" * 64),
            "id": artifact_id,
            "name": artifact_name,
        },
        "release": {"repository": REPOSITORY, "tag": "v0.3.0"},
    }


def windows_provenance(asset_digest: str) -> dict:
    document = {
        "schemaVersion": 1,
        "status": "release-candidate",
        "version": "0.3.0",
        "architecture": "x64",
        "runtimeIdentifier": "win-x64",
        "sourceCommit": SOURCE,
        "validatedSourceCommit": SOURCE,
        "packagingCommit": PACKAGING,
        "artifact": WINDOWS_ASSET,
        "sha256": asset_digest,
        "payloadManifestSha256": "b" * 64,
        "validationEvidenceSha256": "c" * 64,
        "codexRuntime": {
            "source": (
                "https://github.com/openai/codex/releases/download/"
                "rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe"
            ),
            "sha256": "935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d",
        },
        "realDeviceValidated": True,
        "publishableInstaller": True,
        "authenticodeStatus": "NotSigned",
        "signerSubject": None,
        "createdAt": "2026-08-13T00:00:00+00:00",
    }
    document.update(finalized_identity(WINDOWS_ARTIFACT, 123456, 987654))
    return document


def macos_provenance(asset_digest: str) -> dict:
    document = {
        "schemaVersion": 3,
        "status": "release-candidate",
        "version": "0.3.0",
        "platform": "macos",
        "architecture": "arm64",
        "sourceCommit": SOURCE,
        "validatedSourceCommit": SOURCE,
        "packagingCommit": PACKAGING,
        "payloadCommit": SOURCE,
        "asset": {"name": MACOS_ASSET, "sha256": asset_digest},
        "installer": {"executableSha256": "e" * 64, "signature": "adhoc"},
        "companion": {"executableSha256": "f" * 64},
        "sdk": {"name": "macosx", "version": "26.0"},
        "notarized": False,
    }
    document.update(finalized_identity(MACOS_ARTIFACT, 123456, 887654))
    return document


def write_json(path: Path, document: dict) -> None:
    path.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def make_candidate(root: Path) -> tuple[str, str]:
    windows_bytes = b"tiny Windows setup fixture\x00\xff"
    macos_bytes = b"tiny macOS DMG fixture\x00\xfe"
    windows_digest = digest(windows_bytes)
    macos_digest = digest(macos_bytes)
    (root / WINDOWS_ASSET).write_bytes(windows_bytes)
    (root / MACOS_ASSET).write_bytes(macos_bytes)
    (root / WINDOWS_CHECKSUM).write_text(
        f"{windows_digest}  {WINDOWS_ASSET}\n", encoding="utf-8"
    )
    (root / MACOS_CHECKSUM).write_text(
        f"{macos_digest}  {MACOS_ASSET}\n", encoding="utf-8"
    )
    write_json(root / WINDOWS_PROVENANCE, windows_provenance(windows_digest))
    write_json(root / MACOS_PROVENANCE, macos_provenance(macos_digest))
    return windows_digest, macos_digest


def candidate_snapshot(root: Path) -> tuple:
    result = []
    for path in sorted(root.iterdir(), key=lambda item: item.name):
        stat = path.lstat()
        payload = os.readlink(path) if path.is_symlink() else path.read_bytes()
        result.append(
            (path.name, stat.st_mode, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns, payload)
        )
    return tuple(result)


class CandidateSetVerifierTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="cus-v030-candidates-")
        self.root = Path(self.temporary.name)
        self.candidate = self.root / "candidate"
        self.candidate.mkdir()
        self.windows_digest, self.macos_digest = make_candidate(self.candidate)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_verifier(
        self,
        candidate: Path | None = None,
        *,
        source: str = SOURCE,
        packaging: str = PACKAGING,
        summary: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        if candidate is None:
            candidate = self.candidate
        if summary is None:
            summary = self.root / "summary.json"
        return subprocess.run(
            [
                sys.executable,
                str(VERIFIER),
                str(candidate),
                "--validated-source",
                source,
                "--packaging-commit",
                packaging,
                "--output",
                str(summary),
            ],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def mutate_json(self, basename: str, mutation) -> None:
        path = self.candidate / basename
        document = json.loads(path.read_text(encoding="utf-8"))
        mutation(document)
        write_json(path, document)

    def assert_rejected_without_changes(
        self,
        *,
        source: str = SOURCE,
        packaging: str = PACKAGING,
    ) -> None:
        before = candidate_snapshot(self.candidate)
        summary = self.root / "summary.json"
        original_summary = b"pre-existing summary must survive\n"
        summary.write_bytes(original_summary)
        result = self.run_verifier(source=source, packaging=packaging, summary=summary)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("can't open file", result.stderr)
        self.assertEqual(summary.read_bytes(), original_summary)
        self.assertEqual(candidate_snapshot(self.candidate), before)

    def test_valid_six_file_set_writes_exact_summary_without_modifying_inputs(self) -> None:
        before = candidate_snapshot(self.candidate)
        summary = self.root / "nested" / "summary.json"
        result = self.run_verifier(summary=summary)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(summary.read_text(encoding="utf-8")),
            {
                "assets": {
                    MACOS_ASSET: self.macos_digest,
                    WINDOWS_ASSET: self.windows_digest,
                },
                "packagingCommit": PACKAGING,
                "validatedSourceCommit": SOURCE,
                "version": "0.3.0",
            },
        )
        self.assertEqual(candidate_snapshot(self.candidate), before)

    def test_missing_and_extra_candidate_entries_are_rejected(self) -> None:
        for label, mutation in (
            ("missing", lambda: (self.candidate / WINDOWS_CHECKSUM).unlink()),
            ("extra", lambda: (self.candidate / "unexpected.txt").write_text("extra")),
        ):
            with self.subTest(label=label):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                mutation()
                self.assert_rejected_without_changes()

    def test_checksum_mismatch_and_noncanonical_checksum_shapes_are_rejected(self) -> None:
        invalid_lines = (
            ("mismatch", f"{'0' * 64}  {WINDOWS_ASSET}\n"),
            ("uppercase", f"{self.windows_digest.upper()}  {WINDOWS_ASSET}\n"),
            ("one-space", f"{self.windows_digest} {WINDOWS_ASSET}\n"),
            ("extra-line", f"{self.windows_digest}  {WINDOWS_ASSET}\nextra\n"),
            ("wrong-name", f"{self.windows_digest}  renamed.exe\n"),
        )
        for label, content in invalid_lines:
            with self.subTest(label=label):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                (self.candidate / WINDOWS_CHECKSUM).write_text(content, encoding="utf-8")
                self.assert_rejected_without_changes()

    def test_windows_platform_and_signing_policy_is_enforced(self) -> None:
        mutations = (
            ("architecture", lambda data: data.__setitem__("architecture", "arm64")),
            ("runtime", lambda data: data.__setitem__("runtimeIdentifier", "win-arm64")),
            ("authenticode", lambda data: data.__setitem__("authenticodeStatus", "Valid")),
            ("signer", lambda data: data.__setitem__("signerSubject", "CN=Example")),
            ("validated", lambda data: data.__setitem__("realDeviceValidated", False)),
            ("publishable", lambda data: data.__setitem__("publishableInstaller", False)),
        )
        for label, mutation in mutations:
            with self.subTest(label=label):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                self.mutate_json(WINDOWS_PROVENANCE, mutation)
                self.assert_rejected_without_changes()

    def test_macos_platform_policy_is_enforced(self) -> None:
        mutations = (
            ("architecture", lambda data: data.__setitem__("architecture", "x64")),
            ("notarized", lambda data: data.__setitem__("notarized", True)),
        )
        for label, mutation in mutations:
            with self.subTest(label=label):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                self.mutate_json(MACOS_PROVENANCE, mutation)
                self.assert_rejected_without_changes()

    def test_provenance_asset_digests_must_match_streamed_payload_hashes(self) -> None:
        for label, basename, mutation in (
            ("windows", WINDOWS_PROVENANCE, lambda data: data.__setitem__("sha256", "0" * 64)),
            (
                "macos",
                MACOS_PROVENANCE,
                lambda data: data["asset"].__setitem__("sha256", "0" * 64),
            ),
        ):
            with self.subTest(label=label):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                self.mutate_json(basename, mutation)
                self.assert_rejected_without_changes()

    def test_both_platforms_must_bind_the_exact_requested_source_and_packaging_commits(self) -> None:
        cases = (
            ("argument-source", None, "a" * 40, PACKAGING),
            ("argument-packaging", None, SOURCE, "a" * 40),
            (
                "cross-platform-source",
                lambda: self.mutate_json(
                    MACOS_PROVENANCE,
                    lambda data: data.__setitem__("validatedSourceCommit", "a" * 40),
                ),
                SOURCE,
                PACKAGING,
            ),
            (
                "cross-platform-packaging",
                lambda: self.mutate_json(
                    MACOS_PROVENANCE,
                    lambda data: data.__setitem__("packagingCommit", "a" * 40),
                ),
                SOURCE,
                PACKAGING,
            ),
        )
        for label, mutation, source, packaging in cases:
            with self.subTest(label=label):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                if mutation is not None:
                    mutation()
                self.assert_rejected_without_changes(source=source, packaging=packaging)

    def test_ci_artifact_and_release_identity_is_strict(self) -> None:
        mutations = (
            ("version", lambda data: data.__setitem__("version", "0.3.1")),
            ("repository", lambda data: data["ci"].__setitem__("repository", "fork/repo")),
            ("branch", lambda data: data["ci"].__setitem__("branch", "main")),
            ("event", lambda data: data["ci"].__setitem__("event", "workflow_dispatch")),
            ("workflow", lambda data: data["ci"].__setitem__("workflowPath", ".github/workflows/ci.yml")),
            ("run-id", lambda data: data["ci"].__setitem__("runId", 0)),
            ("run-url", lambda data: data["ci"].__setitem__("runUrl", "https://example.invalid/run")),
            ("artifact-id", lambda data: data["artifactRecord"].__setitem__("id", 0)),
            ("artifact-name", lambda data: data["artifactRecord"].__setitem__("name", "wrong")),
            ("artifact-digest", lambda data: data["artifactRecord"].__setitem__("digest", "sha256:not-a-digest")),
            ("release-repository", lambda data: data["release"].__setitem__("repository", "fork/repo")),
            ("release-tag", lambda data: data["release"].__setitem__("tag", "v0.3.1")),
        )
        for label, mutation in mutations:
            with self.subTest(label=label):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                self.mutate_json(WINDOWS_PROVENANCE, mutation)
                self.assert_rejected_without_changes()

    def test_initial_unfinalized_provenance_blocks_are_rejected(self) -> None:
        for missing in ("ci", "artifactRecord", "release"):
            with self.subTest(missing=missing):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                self.mutate_json(WINDOWS_PROVENANCE, lambda data, key=missing: data.pop(key))
                self.assert_rejected_without_changes()

    def test_platform_records_from_different_ci_runs_are_rejected(self) -> None:
        self.mutate_json(
            MACOS_PROVENANCE,
            lambda data: (
                data["ci"].__setitem__("runId", 223456),
                data["ci"].__setitem__(
                    "runUrl",
                    f"https://github.com/{REPOSITORY}/actions/runs/223456",
                ),
            ),
        )
        self.assert_rejected_without_changes()

    def test_summary_cannot_be_created_anywhere_in_candidate_directory(self) -> None:
        for relative in (Path("summary.json"), Path("nested") / "summary.json"):
            with self.subTest(relative=relative):
                shutil.rmtree(self.candidate)
                self.candidate.mkdir()
                make_candidate(self.candidate)
                before = candidate_snapshot(self.candidate)
                summary = self.candidate / relative
                result = self.run_verifier(summary=summary)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertFalse(summary.exists())
                self.assertEqual(candidate_snapshot(self.candidate), before)

    def test_summary_cannot_overwrite_any_candidate_input(self) -> None:
        before = candidate_snapshot(self.candidate)
        result = self.run_verifier(summary=self.candidate / WINDOWS_ASSET)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(candidate_snapshot(self.candidate), before)

    def test_root_and_entry_reparse_points_are_rejected_deterministically(self) -> None:
        for label, flagged in (
            ("root", self.candidate),
            ("entry", self.candidate / WINDOWS_CHECKSUM),
        ):
            with self.subTest(label=label):
                before = candidate_snapshot(self.candidate)
                summary = self.root / f"{label}-summary.json"
                original_summary = b"pre-existing summary must survive\n"
                summary.write_bytes(original_summary)
                flagged_key = os.path.normcase(os.path.abspath(flagged))
                original_lstat = Path.lstat

                def lstat_with_reparse(path: Path):
                    details = original_lstat(path)
                    if os.path.normcase(os.path.abspath(path)) == flagged_key:
                        return types.SimpleNamespace(
                            st_mode=details.st_mode,
                            st_file_attributes=VERIFIER_MODULE.REPARSE_POINT,
                        )
                    return details

                arguments = [
                    str(VERIFIER),
                    str(self.candidate),
                    "--validated-source",
                    SOURCE,
                    "--packaging-commit",
                    PACKAGING,
                    "--output",
                    str(summary),
                ]
                with mock.patch.object(
                    Path, "lstat", autospec=True, side_effect=lstat_with_reparse
                ), mock.patch.object(sys, "argv", arguments):
                    with self.assertRaisesRegex(SystemExit, "reparse point"):
                        VERIFIER_MODULE.main()
                self.assertEqual(summary.read_bytes(), original_summary)
                self.assertEqual(candidate_snapshot(self.candidate), before)

    def test_reparse_attribute_is_detected_for_regular_file_mode(self) -> None:
        path = mock.Mock()
        path.lstat.return_value = types.SimpleNamespace(
            st_mode=stat.S_IFREG,
            st_file_attributes=VERIFIER_MODULE.REPARSE_POINT,
        )
        self.assertTrue(VERIFIER_MODULE.is_link_or_reparse(path))

    @unittest.skipUnless(hasattr(os, "symlink"), "symbolic links are unavailable")
    def test_linked_candidate_entries_are_rejected_where_supported(self) -> None:
        target = self.root / "outside-checksum.txt"
        target.write_text((self.candidate / WINDOWS_CHECKSUM).read_text(encoding="utf-8"), encoding="utf-8")
        (self.candidate / WINDOWS_CHECKSUM).unlink()
        try:
            os.symlink(target, self.candidate / WINDOWS_CHECKSUM)
        except OSError as error:
            self.skipTest(f"symbolic link creation is unavailable: {error}")
        self.assert_rejected_without_changes()

    def test_invalid_commit_arguments_do_not_replace_existing_summary(self) -> None:
        self.assert_rejected_without_changes(source="A" * 40)


if __name__ == "__main__":
    unittest.main(verbosity=2)
