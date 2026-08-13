#!/usr/bin/env python3
"""Exercise the one-case Windows v0.3.0 validation recorder."""

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = REPOSITORY_ROOT / "scripts" / "new-windows-v030-validation-template.py"
RECORDER = REPOSITORY_ROOT / "scripts" / "record-windows-v030-validation.py"
VERIFIER = REPOSITORY_ROOT / "scripts" / "verify-windows-v030-validation.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"


def run(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(RECORDER), *arguments],
        text=True,
        capture_output=True,
        check=False,
    )


def create_template(directory: Path, name: str) -> Path:
    evidence = directory / name
    subprocess.run(
        [
            sys.executable,
            str(TEMPLATE),
            "--source-commit",
            COMMIT,
            "--windows-build",
            "26100",
            "--codex-file-build",
            "151.0.7922.76",
            "--output",
            str(evidence),
        ],
        check=True,
    )
    return evidence


def load_document(evidence: Path) -> dict[str, object]:
    return json.loads(evidence.read_text(encoding="utf-8"))


def assert_success(result: subprocess.CompletedProcess[str]) -> None:
    assert result.returncode == 0, result.stderr


def recorder_module() -> object:
    specification = importlib.util.spec_from_file_location("windows_recorder", RECORDER)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def main() -> None:
    assert RECORDER.is_file(), f"missing recorder: {RECORDER}"
    with tempfile.TemporaryDirectory() as temporary_directory:
        directory = Path(temporary_directory)
        evidence = create_template(directory, "single-case.json")

        assert_success(
            run(
                str(evidence),
                "visual",
                "--layout",
                "restored-collapsed",
                "--theme",
                "light",
                "--language",
                "zh-CN",
                "--scale",
                "100",
            )
        )
        document = load_document(evidence)
        visual = document["cases"]["visual"]  # type: ignore[index]
        selected = next(
            case
            for case in visual
            if (case["layout"], case["theme"], case["language"], case["scale"])
            == ("restored-collapsed", "light", "zh-CN", 100)
        )
        assert selected["result"] == "pass"
        assert all(
            case["result"] == "pending"
            for group in document["cases"].values()  # type: ignore[index]
            for case in group
            if case is not selected
        )
        assert run(
            str(evidence),
            "visual",
            "--layout",
            "restored-collapsed",
            "--theme",
            "light",
            "--language",
            "zh-CN",
            "--scale",
            "100",
        ).returncode != 0
        assert run(
            str(evidence),
            "visual",
            "--layout",
            "missing",
            "--theme",
            "light",
            "--language",
            "zh-CN",
            "--scale",
            "100",
        ).returncode != 0
        assert run(str(evidence), "complete").returncode != 0

        malformed = create_template(directory, "malformed.json")
        malformed_document = load_document(malformed)
        malformed_document["unexpected"] = True
        malformed.write_text(json.dumps(malformed_document), encoding="utf-8")
        original_malformed = malformed.read_bytes()
        assert run(
            str(malformed),
            "geometry",
            "--state",
            "restored-collapsed",
        ).returncode != 0
        assert malformed.read_bytes() == original_malformed

        complete = create_template(directory, "complete.json")
        document = load_document(complete)
        for case in document["cases"]["visual"]:  # type: ignore[index]
            assert_success(
                run(
                    str(complete),
                    "visual",
                    "--layout",
                    case["layout"],
                    "--theme",
                    case["theme"],
                    "--language",
                    case["language"],
                    "--scale",
                    str(case["scale"]),
                )
            )
        for case in document["cases"]["geometry"]:  # type: ignore[index]
            assert_success(run(str(complete), "geometry", "--state", case["state"]))
        for group in ("interaction", "lifecycle"):
            for case in document["cases"][group]:  # type: ignore[index]
                assert_success(run(str(complete), group, "--name", case["name"]))
        assert_success(run(str(complete), "complete"))
        completed = load_document(complete)
        assert re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", completed["completedAt"])
        subprocess.run(
            [sys.executable, str(VERIFIER), str(complete), "--source-commit", COMMIT],
            check=True,
        )

        rollback = create_template(directory, "rollback.json")
        rollback_document = load_document(rollback)
        for group in rollback_document["cases"].values():  # type: ignore[index]
            for case in group:
                case["result"] = "pass"
        rollback.write_text(
            json.dumps(rollback_document, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        original_rollback = rollback.read_bytes()
        module = recorder_module()
        module.verify_completed = lambda path, source_commit: False
        try:
            module.complete(rollback)
        except SystemExit:
            pass
        else:
            raise AssertionError("completion accepted a verifier failure")
        assert rollback.read_bytes() == original_rollback

        verifier_exception = create_template(directory, "verifier-exception.json")
        exception_document = load_document(verifier_exception)
        for group in exception_document["cases"].values():  # type: ignore[index]
            for case in group:
                case["result"] = "pass"
        verifier_exception.write_text(
            json.dumps(exception_document, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        original_exception = verifier_exception.read_bytes()
        module.verify_completed = lambda path, source_commit: (_ for _ in ()).throw(
            OSError("verifier unavailable")
        )
        try:
            module.complete(verifier_exception)
        except OSError as error:
            assert str(error) == "verifier unavailable"
        else:
            raise AssertionError("completion swallowed a verifier exception")
        assert verifier_exception.read_bytes() == original_exception

        class ReparsePoint:
            def lstat(self) -> SimpleNamespace:
                return SimpleNamespace(st_file_attributes=0x400)

        with patch.object(module.os, "name", "nt"):
            assert module.is_windows_reparse_point(ReparsePoint())

    print("PASS: Windows v0.3.0 recorder updates exactly one case atomically")


if __name__ == "__main__":
    main()
