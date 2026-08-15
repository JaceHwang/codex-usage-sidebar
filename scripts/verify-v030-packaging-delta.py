#!/usr/bin/env python3
"""Allow a v0.3.0 packaging commit to differ from validated source only by evidence."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path, PurePosixPath


def git(repository: Path, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def safe_relative_path(value: str) -> str:
    candidate = PurePosixPath(value.replace("\\", "/"))
    if candidate.is_absolute() or not candidate.parts \
            or any(part in ("", ".", "..") for part in candidate.parts):
        raise SystemExit(f"unsafe allowed packaging path: {value}")
    return candidate.as_posix()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True, type=Path)
    parser.add_argument("--validated-source-commit", required=True)
    parser.add_argument("--packaging-commit", required=True)
    parser.add_argument("--allowed-path", action="append", required=True)
    args = parser.parse_args()

    repository = args.repository.resolve(strict=True)
    for label, commit in (
        ("validated source", args.validated_source_commit),
        ("packaging", args.packaging_commit),
    ):
        if re.fullmatch(r"[0-9a-f]{40}", commit) is None:
            raise SystemExit(f"invalid {label} commit")
        git(repository, "cat-file", "-e", f"{commit}^{{commit}}")

    ancestor = git(
        repository,
        "merge-base",
        "--is-ancestor",
        args.validated_source_commit,
        args.packaging_commit,
        check=False,
    )
    if ancestor.returncode != 0:
        raise SystemExit("validated source commit is not an ancestor of packaging commit")

    allowed = {safe_relative_path(path) for path in args.allowed_path}
    changed = {
        line.strip().replace("\\", "/")
        for line in git(
            repository,
            "diff",
            "--name-only",
            "--no-renames",
            args.validated_source_commit,
            args.packaging_commit,
            "--",
        ).stdout.splitlines()
        if line.strip()
    }
    unexpected = sorted(changed.difference(allowed))
    if unexpected:
        raise SystemExit(
            "post-validation source changes are not allowed: " + ", ".join(unexpected)
        )
    print(
        "PASS: packaging commit differs from validated source only by approved evidence"
    )


if __name__ == "__main__":
    main()
