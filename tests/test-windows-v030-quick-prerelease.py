#!/usr/bin/env python3
"""Exercise strict redacted smoke evidence for the v0.3.0 rc.1 prerelease."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECORDER = ROOT / "scripts" / "record-windows-v030-quick-prerelease.py"
VERIFIER = ROOT / "scripts" / "verify-windows-v030-quick-prerelease.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"


def run(script: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(script), *arguments],
        text=True,
        capture_output=True,
        check=False,
    )


def require_success(result: subprocess.CompletedProcess[str]) -> None:
    assert result.returncode == 0, result.stderr


def create_completed_evidence(directory: Path, name: str) -> Path:
    evidence = directory / name
    require_success(
        run(
            RECORDER,
            "init",
            str(evidence),
            "--source-commit",
            COMMIT,
            "--windows-build",
            "26100",
            "--codex-file-build",
            "151.0.7922.76",
        )
    )
    require_success(run(RECORDER, "complete", str(evidence)))
    return evidence


def require_rejection(evidence: Path) -> None:
    result = run(VERIFIER, str(evidence), "--source-commit", COMMIT)
    assert result.returncode != 0, result.stdout


def document(evidence: Path) -> dict[str, object]:
    return json.loads(evidence.read_text(encoding="utf-8"))


def write_document(evidence: Path, value: dict[str, object]) -> None:
    evidence.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary_directory:
        directory = Path(temporary_directory)
        evidence = create_completed_evidence(directory, "complete.json")
        require_success(run(VERIFIER, str(evidence), "--source-commit", COMMIT))
        require_success(run(RECORDER, "verify", str(evidence), "--source-commit", COMMIT))

        formal_shape = directory / "formal-shape.json"
        write_document(
            formal_shape,
            {
                "schemaVersion": 1,
                "version": "0.3.0",
                "sourceCommit": COMMIT,
                "architecture": "x64",
                "windowsBuild": 26100,
                "codexFileBuild": "151.0.7922.76",
                "completedAt": "2026-08-13T00:00:00Z",
                "cases": {},
            },
        )
        require_rejection(formal_shape)

        mutations: tuple[tuple[str, object], ...] = (
            ("unknown key", ("unexpected", True)),
            ("invalid source", ("sourceCommit", "ABCDEF")),
            ("wrong source argument", None),
            ("Windows ARM64", ("architecture", "arm64")),
            ("pre-Windows-11", ("windowsBuild", 21999)),
            ("invalid Codex build", ("codexFileBuild", "151.0")),
            ("non-UTC time", ("completedAt", "2026-08-13T00:00:00+00:00")),
            ("embedded failure", ("embeddedPayload", "fail")),
            ("manager failure", ("manager", "pending")),
            ("runtime failure", ("runtime", "skip")),
            ("probe includes text", ("includesText", True)),
            ("probe has raw names", ("rawNodeNameCount", 1)),
        )
        for label, mutation in mutations:
            invalid = directory / (label.replace(" ", "-") + ".json")
            value = document(evidence)
            if label == "wrong source argument":
                write_document(invalid, value)
                assert run(
                    VERIFIER,
                    str(invalid),
                    "--source-commit",
                    "fedcba9876543210fedcba9876543210fedcba98",
                ).returncode != 0
                continue
            key, replacement = mutation  # type: ignore[misc]
            if key in {"includesText", "rawNodeNameCount"}:
                value["smoke"]["redactedProbe"][key] = replacement  # type: ignore[index]
            elif key in {"embeddedPayload", "manager", "runtime"}:
                value["smoke"][key] = replacement  # type: ignore[index]
            else:
                value[key] = replacement
            write_document(invalid, value)
            require_rejection(invalid)

        incomplete = directory / "incomplete.json"
        require_success(
            run(
                RECORDER,
                "init",
                str(incomplete),
                "--source-commit",
                COMMIT,
                "--windows-build",
                "26100",
                "--codex-file-build",
                "151.0.7922.76",
            )
        )
        incomplete_document = document(incomplete)
        incomplete_document["smoke"]["manager"] = "pending"  # type: ignore[index]
        write_document(incomplete, incomplete_document)
        assert run(RECORDER, "complete", str(incomplete)).returncode != 0

    print("PASS: v0.3.0 rc.1 quick evidence is fixed-schema, passing, and redacted")


if __name__ == "__main__":
    main()
