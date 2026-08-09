#!/usr/bin/env bash
set -euo pipefail

default_codex_home="$HOME/Library/Application Support/CodexUsageSidebar/CodexHome"
codex_home="${CODEX_HOME:-}"
if [[ -z "$codex_home" && -d "$default_codex_home" ]]; then
  codex_home="$default_codex_home"
fi

if (($#)); then
  if [[ "$1" == "--codex-home" && $# -eq 2 ]]; then
    codex_home="$2"
  else
    printf 'usage: %s [--codex-home PATH]\n' "$0" >&2
    exit 64
  fi
fi

if [[ -x /Applications/ChatGPT.app/Contents/Resources/codex ]]; then
  codex_binary=/Applications/ChatGPT.app/Contents/Resources/codex
elif command -v codex >/dev/null 2>&1; then
  codex_binary="$(command -v codex)"
else
  printf 'FAIL: no Codex app-server binary found\n' >&2
  exit 1
fi

probe_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-usage-probe.XXXXXX")"
input_fifo="$probe_root/input"
output_file="$probe_root/output.jsonl"
error_file="$probe_root/stderr.log"
server_pid=

cleanup() {
  exec 3>&- || true
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$probe_root"
}
trap cleanup EXIT

mkfifo "$input_fifo"
exec 3<>"$input_fifo"
if [[ -n "$codex_home" ]]; then
  env CODEX_HOME="$codex_home" \
    "$codex_binary" app-server --stdio \
    <"$input_fifo" >"$output_file" 2>"$error_file" &
else
  "$codex_binary" app-server --stdio \
    <"$input_fifo" >"$output_file" 2>"$error_file" &
fi
server_pid=$!

printf '%s\n' \
  '{"method":"initialize","id":1,"params":{"clientInfo":{"name":"codex-usage-sidebar-probe","title":"Codex Usage Sidebar Probe","version":"1.0.0"},"capabilities":{"experimentalApi":true,"requestAttestation":false}}}' \
  '{"method":"initialized"}' \
  '{"method":"account/rateLimits/read","id":2}' >&3

snapshot=
for _ in {1..120}; do
  snapshot="$(
    jq -Rsr '
      [
        split("\n")[] |
        fromjson? |
        select(.id == 2) |
        .result as $result |
        (
          $result.rateLimitsByLimitId.codex //
          $result.rateLimits
        ) as $bucket |
        select(
          ($bucket.primary.usedPercent | type) == "number" and
          ($bucket.primary.resetsAt | type) == "number"
        ) |
        {
          used: $bucket.primary.usedPercent,
          reset: $bucket.primary.resetsAt,
          bank_count: (
            if ($result.rateLimitResetCredits.availableCount | type) == "number"
            then ($result.rateLimitResetCredits.availableCount | floor | tostring)
            else "unavailable"
            end
          ),
          bank_expiry: (
            [
              $result.rateLimitResetCredits.credits[]? |
              .expiresAt |
              select(type == "number")
            ] |
            if length > 0 then (min | floor | tostring) else "none" end
          )
        }
      ] |
      last //
      empty |
      "\(((100 - .used) | round)) \((.reset | floor)) \(.bank_count) \(.bank_expiry)"
    ' "$output_file" 2>/dev/null || true
  )"
  if [[ -n "$snapshot" ]]; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    printf 'FAIL: Codex app-server exited before returning rate limits\n' >&2
    exit 1
  fi
  sleep 0.05
done

if [[ -z "$snapshot" ]]; then
  printf 'FAIL: timed out waiting for a numeric Codex rate-limit bucket\n' >&2
  exit 1
fi

read -r remaining reset_epoch bank_count bank_earliest_expiry <<<"$snapshot"
printf \
  'remaining=%s reset_epoch=%s bank_count=%s bank_earliest_expiry=%s\n' \
  "$remaining" \
  "$reset_epoch" \
  "$bank_count" \
  "$bank_earliest_expiry"
