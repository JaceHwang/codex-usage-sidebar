#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_root="$repo_root/plugins/codex-usage-sidebar"
marketplace="$repo_root/.agents/plugins/marketplace.json"
manifest="$plugin_root/.codex-plugin/plugin.json"
companion="$plugin_root/assets/Codex Usage Sidebar.app"

required=(
  README.md README.zh-CN.md LICENSE CHANGELOG.md CONTRIBUTING.md SECURITY.md SUPPORT.md
  CODE_OF_CONDUCT.md .agents/plugins/marketplace.json .github/workflows/ci.yml
  docs/INSTALL.md docs/INSTALL_FOR_AGENTS.md docs/ARCHITECTURE.md docs/TROUBLESHOOTING.md
  docs/PRIVACY.md docs/images/hero.svg docs/images/placement.svg docs/images/architecture.svg
  plugins/codex-usage-sidebar/.codex-plugin/plugin.json
  plugins/codex-usage-sidebar/assets/PROVENANCE.json
  plugins/codex-usage-sidebar/assets/Codex\ Usage\ Sidebar.app/Contents/MacOS/CodexUsageSidebar
  plugins/codex-usage-sidebar/hooks/hooks.json plugins/codex-usage-sidebar/native/Package.swift
)

for relative in "${required[@]}"; do
  [[ -e "$repo_root/$relative" ]] || { printf 'missing required file: %s\n' "$relative" >&2; exit 66; }
done

/usr/bin/python3 - "$repo_root" <<'PY'
import json
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
marketplace = json.loads((root / ".agents/plugins/marketplace.json").read_text())
assert marketplace["name"] == "codex-usage-sidebar"
entries = marketplace["plugins"]
assert len(entries) == 1
entry = entries[0]
assert entry["name"] == "codex-usage-sidebar"
assert entry["source"] == {"source": "local", "path": "./plugins/codex-usage-sidebar"}
assert entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}
assert entry["category"] == "Productivity"

manifest = json.loads((root / "plugins/codex-usage-sidebar/.codex-plugin/plugin.json").read_text())
assert manifest["name"] == "codex-usage-sidebar"
assert manifest["version"].count("+codex.") == 1
assert manifest["skills"] == "./skills/"

json.loads((root / "plugins/codex-usage-sidebar/hooks/hooks.json").read_text())

provenance_path = root / "plugins/codex-usage-sidebar/assets/PROVENANCE.json"
provenance = json.loads(provenance_path.read_text())
source_commit = provenance["sourceCommit"]
if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
    raise SystemExit("invalid provenance source commit")

if os.environ.get("CUS_REBUILT_PAYLOAD") != "1":
    executable = root / (
        "plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/"
        "Contents/MacOS/CodexUsageSidebar"
    )
    actual_sha = hashlib.sha256(executable.read_bytes()).hexdigest()
    expected_sha = provenance["companion"]["executableSha256"]
    if actual_sha != expected_sha:
        raise SystemExit(
            f"marketplace companion hash differs from provenance: {actual_sha} != {expected_sha}"
        )
    subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{source_commit}^{{commit}}"],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    subprocess.run(
        [
            "git", "-C", str(root), "diff", "--quiet", source_commit, "HEAD", "--",
            "plugins/codex-usage-sidebar",
            ":(exclude)plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app",
            ":(exclude)plugins/codex-usage-sidebar/assets/PROVENANCE.json",
        ],
        check=True,
    )

forbidden = [
    (re.compile(r"/Users/[^/\s]+"), "absolute macOS user path"),
    (re.compile(r"(?:gho_|github_pat_)[A-Za-z0-9_]{20,}"), "GitHub token"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS key"),
    (re.compile(r"sk-[A-Za-z0-9_-]{20,}"), "API key"),
    (re.compile(r"BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY"), "private key"),
    (re.compile(r"\b(?:TBD|TODO)\b"), "placeholder"),
]

text_files = []
generated_parts = {".git", ".build", ".dist", ".swiftpm"}
for path in root.rglob("*"):
    if not path.is_file() or generated_parts.intersection(path.parts):
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    text_files.append((path, text))
    relative = path.relative_to(root)
    if relative == Path("scripts/validate-public-repo.sh"):
        continue
    for pattern, label in forbidden:
        if pattern.search(text):
            raise SystemExit(f"{relative}: contains forbidden {label}")

link_pattern = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
for path, text in text_files:
    if path.suffix.lower() != ".md":
        continue
    for raw in link_pattern.findall(text):
        target = raw.strip().split()[0].strip("<>")
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        file_part = target.split("#", 1)[0]
        if not file_part:
            continue
        resolved = (path.parent / file_part).resolve()
        try:
            resolved.relative_to(root)
        except ValueError:
            raise SystemExit(f"{path.relative_to(root)}: link escapes repository: {target}")
        if not resolved.exists():
            raise SystemExit(f"{path.relative_to(root)}: broken relative link: {target}")

for forbidden_path in [root / ".superpowers", root / "docs/verification"]:
    if forbidden_path.exists():
        raise SystemExit(f"private development artifact present: {forbidden_path.relative_to(root)}")

print("JSON, privacy, placeholder, and Markdown link checks passed")
PY

/usr/bin/plutil -lint "$companion/Contents/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict "$companion"
[[ -x "$companion/Contents/MacOS/CodexUsageSidebar" ]]
[[ -x "$plugin_root/scripts/sidebar-control.sh" ]]
[[ -x "$plugin_root/scripts/build-companion.sh" ]]

for svg in "$repo_root"/docs/images/*.svg; do
  /usr/bin/xmllint --noout "$svg"
done

printf 'PASS: public repository layout, manifests, links, privacy, SVG, and companion signature\n'
