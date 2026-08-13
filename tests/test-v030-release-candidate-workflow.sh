#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${V030_WORKFLOW_UNDER_TEST:-$repo_root/.github/workflows/v030-release-candidates.yml}"
[[ -f "$workflow" ]] || { printf 'missing v0.3.0 candidate workflow\n' >&2; exit 1; }

python3 - "$workflow" <<'PY'
import re
import sys
from pathlib import Path


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def clean_value(value):
    return re.sub(r"\s+#.*$", "", value).strip()


def exact_field(lines, indent, key, context):
    pattern = re.compile(rf"^ {{{indent}}}{re.escape(key)}:\s*(.*?)\s*$")
    values = [clean_value(match.group(1)) for line in lines if (match := pattern.match(line))]
    require(len(values) == 1, f"{context} must define {key} exactly once")
    return values[0]


def release_job_lines(lines):
    jobs = [index for index, line in enumerate(lines) if line == "jobs:"]
    require(len(jobs) == 1, "workflow must define one top-level jobs mapping")
    job_pattern = re.compile(r"^  ([A-Za-z0-9_-]+):\s*(?:#.*)?$")
    jobs_found = [
        (index, match.group(1))
        for index, line in enumerate(lines[jobs[0] + 1 :], start=jobs[0] + 1)
        if (match := job_pattern.match(line))
    ]
    release_jobs = [item for item in jobs_found if item[1] == "release-bundle"]
    require(len(release_jobs) == 1, "workflow must define one release-bundle job")
    start = release_jobs[0][0]
    end = next((index for index, _ in jobs_found if index > start), len(lines))
    return lines[start + 1 : end]


def step_blocks(job):
    steps_indexes = [index for index, line in enumerate(job) if line == "    steps:"]
    require(len(steps_indexes) == 1, "release-bundle must define one steps sequence")
    start = steps_indexes[0] + 1
    step_pattern = re.compile(r"^      - ([A-Za-z0-9_-]+):\s*(.*?)\s*$")
    starts = [index for index in range(start, len(job)) if step_pattern.match(job[index])]
    require(starts, "release-bundle must contain steps")
    result = []
    for position, step_start in enumerate(starts):
        step_end = starts[position + 1] if position + 1 < len(starts) else len(job)
        block = job[step_start:step_end]
        first = step_pattern.match(block[0])
        result.append((block, {first.group(1): clean_value(first.group(2))}))
    return result


def step_fields(step):
    block, fields = step
    fields = dict(fields)
    pattern = re.compile(r"^        ([A-Za-z0-9_-]+):\s*(.*?)\s*$")
    for line in block[1:]:
        match = pattern.match(line)
        if match:
            key = match.group(1)
            require(key not in fields, f"release-bundle step repeats field: {key}")
            fields[key] = clean_value(match.group(2))
    return fields


def step_with(step):
    block, _ = step
    starts = [index for index, line in enumerate(block) if line == "        with:"]
    if not starts:
        return {}, {}
    require(len(starts) == 1, "release-bundle step repeats with mapping")
    start = starts[0] + 1
    field_pattern = re.compile(r"^          ([A-Za-z0-9_-]+):\s*(.*?)\s*$")
    values = {}
    blocks = {}
    index = start
    while index < len(block):
        line = block[index]
        if line and len(line) - len(line.lstrip(" ")) <= 8:
            break
        match = field_pattern.match(line)
        if not match:
            index += 1
            continue
        key = match.group(1)
        require(key not in values, f"release-bundle with mapping repeats field: {key}")
        value = clean_value(match.group(2))
        values[key] = value
        index += 1
        if value == "|":
            scalar = []
            while index < len(block) and (not block[index] or block[index].startswith("            ")):
                scalar.append(block[index][12:] if block[index] else "")
                index += 1
            blocks[key] = scalar
    return values, blocks


def step_run(step):
    block, _ = step
    starts = [index for index, line in enumerate(block) if line == "        run: |"]
    require(len(starts) == 1, "stage-and-verify step must define one literal run block")
    result = []
    for line in block[starts[0] + 1 :]:
        require(not line or line.startswith("          "), "stage-and-verify run block has invalid indentation")
        result.append(line[10:] if line else "")
    return result


def executable_shell_lines(lines):
    heredoc_pattern = re.compile(
        r"(?<!<)<<(?P<tabs>-)?\s*(?:'(?P<single>[^']+)'|\"(?P<double>[^\"]+)\"|\\(?P<escaped>[A-Za-z_][A-Za-z0-9_]*)|(?P<bare>[A-Za-z_][A-Za-z0-9_]*))"
    )
    result = []
    pending_heredocs = []
    for line in lines:
        if pending_heredocs:
            delimiter, strip_tabs = pending_heredocs[0]
            candidate = line.lstrip("\t") if strip_tabs else line
            if candidate == delimiter:
                pending_heredocs.pop(0)
            continue
        result.append(line)
        matches = list(heredoc_pattern.finditer(line))
        unparsed = heredoc_pattern.sub("", line)
        unparsed = re.sub(r"(?<!<)<<<(?!<)", "", unparsed)
        require("<<" not in unparsed, "stage-and-verify run block uses unsupported heredoc syntax")
        for match in matches:
            delimiter = (
                match.group("single")
                or match.group("double")
                or match.group("escaped")
                or match.group("bare")
            )
            pending_heredocs.append((delimiter, match.group("tabs") is not None))
    require(not pending_heredocs, "stage-and-verify run block contains an unterminated heredoc")
    return result


def logical_shell_lines(lines):
    result = []
    pending = ""
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        pending = f"{pending} {stripped}".strip()
        if pending.endswith("\\"):
            pending = pending[:-1].rstrip()
        else:
            result.append(pending)
            pending = ""
    require(not pending, "stage-and-verify run block ends with a continuation")
    return result

workflow = Path(sys.argv[1]).read_text(encoding="utf-8")
workflow_lines = workflow.splitlines()
required = (
    "branches: [v0.3.0]",
    "permissions:\n  contents: read",
    "runs-on: windows-2025",
    "runs-on: macos-26",
    "DEVELOPER_DIR: /Applications/Xcode_26.5.app/Contents/Developer",
    "docs/validation/windows-v0.3.0.json",
    "scripts/build-windows-v030-setup.ps1",
    "scripts/verify-windows-v030-setup.ps1",
    "scripts/build-macos-v030-installer.sh",
    "scripts/package-macos-v030-installer.sh",
    "scripts/verify-macos-v030-installer-package.sh",
    "scripts/finalize-windows-v030-provenance.py",
    "scripts/finalize-macos-v030-provenance.py",
    "codex-usage-sidebar-v0.3.0-windows-x64-candidate",
    "codex-usage-sidebar-v0.3.0-macos-arm64-candidate",
    "codex-usage-sidebar-v0.3.0-windows-x64-provenance",
    "codex-usage-sidebar-v0.3.0-macos-arm64-provenance",
)
for marker in required:
    if marker not in workflow:
        raise SystemExit(f"v0.3.0 candidate workflow is missing: {marker}")

for forbidden in (
    "contents: write",
    "gh release",
    "softprops/action-gh-release",
    "release create",
    "codex-usage-sidebar-v0.2.3-macos-arm64.dmg",
    "win-arm64",
    "windows-arm64",
):
    if forbidden.lower() in workflow.lower():
        raise SystemExit(f"v0.3.0 candidate workflow contains forbidden publication or asset marker: {forbidden}")

release_job = release_job_lines(workflow_lines)
require(
    exact_field(release_job, 4, "runs-on", "release-bundle") == "ubuntu-24.04",
    "release-bundle must run on ubuntu-24.04",
)
require(
    exact_field(release_job, 4, "needs", "release-bundle") == "[windows-x64, macos-arm64]",
    "release-bundle must need exactly windows-x64 and macos-arm64",
)
steps = step_blocks(release_job)
parsed_steps = [(step, step_fields(step), *step_with(step)) for step in steps]

checkout_pin = "actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803"
checkout_steps = [item for item in parsed_steps if item[1].get("uses", "").startswith("actions/checkout@")]
require(len(checkout_steps) == 1, "release-bundle must contain exactly one checkout step")
require(checkout_steps[0][1]["uses"] == checkout_pin, "release-bundle checkout must use the pinned action")
require(
    checkout_steps[0][2] == {"ref": "${{ github.sha }}"},
    "release-bundle checkout must use only ref: ${{ github.sha }}",
)

downloads = (
    ("codex-usage-sidebar-v0.3.0-windows-x64-candidate", "${{ runner.temp }}/v030-downloads/windows-candidate"),
    ("codex-usage-sidebar-v0.3.0-windows-x64-provenance", "${{ runner.temp }}/v030-downloads/windows-provenance"),
    ("codex-usage-sidebar-v0.3.0-macos-arm64-candidate", "${{ runner.temp }}/v030-downloads/macos-candidate"),
    ("codex-usage-sidebar-v0.3.0-macos-arm64-provenance", "${{ runner.temp }}/v030-downloads/macos-provenance"),
)
download_pin = "actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131"
download_steps = [item for item in parsed_steps if item[1].get("uses", "").startswith("actions/download-artifact@")]
require(len(download_steps) == 4, "release-bundle must contain exactly four download steps")
require(
    all(item[1]["uses"] == download_pin for item in download_steps),
    "release-bundle downloads must use the pinned action",
)
actual_downloads = [(item[2].get("name"), item[2].get("path")) for item in download_steps]
require(
    len(set(actual_downloads)) == 4 and set(actual_downloads) == set(downloads),
    "release-bundle downloads must bind the four artifact names to isolated paths",
)
require(
    all(set(item[2]) == {"name", "path"} for item in download_steps),
    "release-bundle download mappings must contain only name and path",
)

expected_release_files = (
    "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe",
    "WINDOWS-V030-SHA256SUMS.txt",
    "WINDOWS-V030-PROVENANCE.final.json",
    "codex-usage-sidebar-v0.3.0-macos-arm64.dmg",
    "MACOS-V030-SHA256SUMS.txt",
    "MACOS-V030-PROVENANCE.final.json",
)
expected_upload_paths = tuple(
    f"${{{{ runner.temp }}}}/release-bundle/{filename}" for filename in expected_release_files
)
upload_pin = "actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f"
upload_steps = [item for item in parsed_steps if item[1].get("uses", "").startswith("actions/upload-artifact@")]
require(len(upload_steps) == 1, "release-bundle must contain exactly one upload step")
upload = upload_steps[0]
require(upload[1]["uses"] == upload_pin, "release-bundle upload must use the pinned action")
require(
    upload[2] == {
        "name": "codex-usage-sidebar-v0.3.0-release-bundle",
        "path": "|",
        "if-no-files-found": "error",
    },
    "release-bundle upload mapping must contain the exact name, path, and missing-file policy",
)
uploaded_paths = tuple(line for line in upload[3].get("path", []) if line)
require(
    len(uploaded_paths) == 6 and set(uploaded_paths) == set(expected_upload_paths),
    "release-bundle upload must list exactly six fully rooted release paths",
)
require(
    all(path.startswith("${{ runner.temp }}/release-bundle/") for path in uploaded_paths),
    "release-bundle upload paths cannot be bare filenames",
)
require(
    all("V030-RELEASE-SUMMARY.json" not in path for path in uploaded_paths),
    "release verification summary must not be uploaded as a release asset",
)

stage_steps = [item for item in parsed_steps if item[1].get("name") == "Stage and verify exact release bundle"]
require(len(stage_steps) == 1, "release-bundle must contain one stage-and-verify step")
stage = stage_steps[0]
require(
    stage[1] == {
        "name": "Stage and verify exact release bundle",
        "shell": "bash",
        "run": "|",
    },
    "stage-and-verify step must contain only its exact name, shell, and run fields",
)
run = executable_shell_lines(step_run(stage[0]))
logical = logical_shell_lines(run)
run_text = "\n".join(run)
function_match = re.search(r"(?ms)^require_exact_files\(\) \{\n(?P<body>.*?)^\}$", run_text)
require(function_match is not None, "stage-and-verify step must define require_exact_files")
function_lines = logical_shell_lines(function_match.group("body").splitlines())
for guard in (
    'test -d "$directory"',
    'test ! -L "$directory"',
    'actual="$(find "$directory" -mindepth 1 -maxdepth 1 -printf \'%f\\n\' | LC_ALL=C sort)"',
    'actual_count="$(find "$directory" -mindepth 1 -maxdepth 1 -printf \'x\' | wc -c)"',
    'expected="$(printf \'%s\\n\' "$@" | LC_ALL=C sort)"',
    'test "$actual" = "$expected"',
    'test "$actual_count" -eq "$#"',
    'test -f "$directory/$entry"',
    'test ! -L "$directory/$entry"',
):
    require(guard in function_lines, f"release-bundle lacks executable exact-file guard: {guard}")

expected_calls = (
    'require_exact_files "$downloads/windows-candidate" codex-usage-sidebar-v0.3.0-windows-x64-setup.exe WINDOWS-V030-PROVENANCE.json WINDOWS-V030-SHA256SUMS.txt',
    'require_exact_files "$downloads/windows-provenance" WINDOWS-V030-PROVENANCE.final.json',
    'require_exact_files "$downloads/macos-candidate" codex-usage-sidebar-v0.3.0-macos-arm64.dmg MACOS-V030-PROVENANCE.json MACOS-V030-SHA256SUMS.txt',
    'require_exact_files "$downloads/macos-provenance" MACOS-V030-PROVENANCE.final.json',
)
for call in expected_calls:
    require(call in logical, f"release-bundle lacks exact artifact validation call: {call}")

copies = (
    ("windows-candidate", "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe"),
    ("windows-candidate", "WINDOWS-V030-SHA256SUMS.txt"),
    ("windows-provenance", "WINDOWS-V030-PROVENANCE.final.json"),
    ("macos-candidate", "codex-usage-sidebar-v0.3.0-macos-arm64.dmg"),
    ("macos-candidate", "MACOS-V030-SHA256SUMS.txt"),
    ("macos-provenance", "MACOS-V030-PROVENANCE.final.json"),
)
expected_copies = {
    f'install -m 0644 "$downloads/{directory}/{filename}" "$release_bundle/"'
    for directory, filename in copies
}
actual_copies = {line for line in logical if line.startswith("install -m 0644 ")}
require(actual_copies == expected_copies, "release-bundle must stage exactly six source-bound files")

validated_source = 'validated_source="$(python3 -c \'import json; print(json.load(open("docs/validation/windows-v0.3.0.json"))["sourceCommit"])\')"'
require(validated_source in logical, "release-bundle must read S from the Windows validation JSON")
verifier = (
    "python3 scripts/verify-v030-candidate-set.py \"$release_bundle\" "
    "--validated-source \"$validated_source\" "
    "--packaging-commit '${{ github.sha }}' "
    "--output \"$RUNNER_TEMP/V030-RELEASE-SUMMARY.json\""
)
require(verifier in logical, "release-bundle must verify exact S and P with an external summary")
require(
    not any("--output \"$release_bundle/" in line for line in logical),
    "release verification summary must remain outside the candidate root",
)
PY

if [[ "${V030_SKIP_MUTATION_TESTS:-0}" != 1 ]]; then
  mutation_root="$(mktemp -d)"
  trap 'rm -rf "$mutation_root"' EXIT
  python3 - \
    "$workflow" \
    "$mutation_root/comment.yml" \
    "$mutation_root/run-scalar.yml" \
    "$mutation_root/continue-error.yml" \
    "$mutation_root/heredoc.yml" \
    "$mutation_root/escaped-heredoc.yml" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")

comment_mutation = source.replace(
    "    runs-on: ubuntu-24.04\n    needs: [windows-x64, macos-arm64]",
    "    # runs-on: ubuntu-24.04\n    needs: [windows-x64, macos-arm64]",
    1,
)
if comment_mutation == source:
    raise SystemExit("could not construct commented-runner workflow mutation")
Path(sys.argv[2]).write_text(comment_mutation, encoding="utf-8")

download_mapping = """        uses: actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131 # v7
        with:
          name: codex-usage-sidebar-v0.3.0-windows-x64-candidate
          path: ${{ runner.temp }}/v030-downloads/windows-candidate
"""
run_scalar_mutation = source.replace(
    download_mapping,
    """        run: |
          uses: actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131 # v7
          with:
            name: codex-usage-sidebar-v0.3.0-windows-x64-candidate
            path: ${{ runner.temp }}/v030-downloads/windows-candidate
""",
    1,
)
if run_scalar_mutation == source:
    raise SystemExit("could not construct run-scalar download workflow mutation")
Path(sys.argv[3]).write_text(run_scalar_mutation, encoding="utf-8")

continue_error_mutation = source.replace(
    """      - name: Stage and verify exact release bundle
        shell: bash
        run: |
""",
    """      - name: Stage and verify exact release bundle
        shell: bash
        continue-on-error: true
        run: |
""",
    1,
)
if continue_error_mutation == source:
    raise SystemExit("could not construct continue-on-error workflow mutation")
Path(sys.argv[4]).write_text(continue_error_mutation, encoding="utf-8")

verifier = """          python3 scripts/verify-v030-candidate-set.py "$release_bundle" \\
            --validated-source "$validated_source" \\
            --packaging-commit '${{ github.sha }}' \\
            --output "$RUNNER_TEMP/V030-RELEASE-SUMMARY.json"
"""
heredoc_mutation = source.replace(
    verifier,
    """          cat <<'IGNORED_VERIFIER'
          python3 scripts/verify-v030-candidate-set.py "$release_bundle" \\
            --validated-source "$validated_source" \\
            --packaging-commit '${{ github.sha }}' \\
            --output "$RUNNER_TEMP/V030-RELEASE-SUMMARY.json"
          IGNORED_VERIFIER
          printf '{}\\n' >"$RUNNER_TEMP/V030-RELEASE-SUMMARY.json"
""",
    1,
)
if heredoc_mutation == source:
    raise SystemExit("could not construct non-executing verifier workflow mutation")
Path(sys.argv[5]).write_text(heredoc_mutation, encoding="utf-8")

escaped_heredoc_mutation = source.replace(
    verifier,
    """          cat <<\\IGNORED_VERIFIER
          python3 scripts/verify-v030-candidate-set.py "$release_bundle" \\
            --validated-source "$validated_source" \\
            --packaging-commit '${{ github.sha }}' \\
            --output "$RUNNER_TEMP/V030-RELEASE-SUMMARY.json"
          IGNORED_VERIFIER
          printf '{}\\n' >"$RUNNER_TEMP/V030-RELEASE-SUMMARY.json"
""",
    1,
)
if escaped_heredoc_mutation == source:
    raise SystemExit("could not construct escaped-heredoc verifier workflow mutation")
Path(sys.argv[6]).write_text(escaped_heredoc_mutation, encoding="utf-8")
PY

  mutation_failure=0
  for mutation in comment run-scalar continue-error heredoc escaped-heredoc; do
    if V030_SKIP_MUTATION_TESTS=1 \
      V030_WORKFLOW_UNDER_TEST="$mutation_root/$mutation.yml" \
      "$0" >/dev/null 2>&1; then
      printf 'v0.3.0 workflow test accepted non-configuration text: %s\n' "$mutation" >&2
      mutation_failure=1
    fi
  done
  (( mutation_failure == 0 )) || exit 1
fi

printf 'PASS: exact v0.3.0 workflow builds Windows x64 and macOS arm64 candidates without publishing\n'
