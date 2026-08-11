#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ci="$repo_root/.github/workflows/ci.yml"
publisher="$repo_root/.github/workflows/publish-installer.yml"
frozen_commit="a72b4636ddf99fa4c1d4660b3e281376be361711"

python3 - "$ci" "$publisher" "$frozen_commit" <<'PY'
import sys
from pathlib import Path

ci = Path(sys.argv[1]).read_text(encoding="utf-8")
publisher = Path(sys.argv[2]).read_text(encoding="utf-8")
commit = sys.argv[3]

binding = f"FROZEN_V023_INSTALLER_SOURCE_COMMIT: {commit}"
if binding not in ci or binding not in publisher:
    raise SystemExit("stable v0.2.3 workflows are not bound to the published source commit")

if ci.count("if: github.sha == env.FROZEN_V023_INSTALLER_SOURCE_COMMIT") < 3:
    raise SystemExit("future CI commits can still upload stable v0.2.3 artifacts")

required_publisher_guards = (
    "test \"$(jq -r '.head_sha' <<<\"$run\")\" = \"$FROZEN_V023_INSTALLER_SOURCE_COMMIT\"",
    "--pattern 'INSTALLER-PROVENANCE.json'",
    "test \"$(jq -r '.installerSourceCommit' \"$RUNNER_TEMP/release/INSTALLER-PROVENANCE.json\")\" = \"$FROZEN_V023_INSTALLER_SOURCE_COMMIT\"",
)
for guard in required_publisher_guards:
    if guard not in publisher:
        raise SystemExit(f"stable v0.2.3 publisher is missing freeze guard: {guard}")

print("PASS: macOS v0.2.3 CI artifacts and publisher are frozen to the published source")
PY
