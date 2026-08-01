# Architecture

<p align="center">
  <img src="images/architecture.svg" alt="Codex Usage Sidebar architecture" width="850">
</p>

## Components

1. **Codex plugin marketplace entry** — makes the plugin installable through the Codex CLI.
2. **SessionStart hook** — ensures the external companion payload is current and synchronizes the
   observed sidebar state at each new task boundary.
3. **Control script** — atomically installs, repairs, reports, and removes a user LaunchAgent.
4. **Native AppKit companion** — reads quota snapshots, resolves theme and placement, and renders an
   independent non-activating overlay.
5. **SidebarCore** — pure decoding, formatting, layout, refresh, and surface-classification logic
   covered by Swift tests.

## Data flow

The companion discovers the running `com.openai.codex` bundle and launches its current
`codex app-server` executable over local stdio. It initializes JSON-RPC, reads rate limits, and
subscribes to updates. No account token is read by the companion.

The placement adapter reads the Codex accessibility tree when macOS grants permission. It performs
a shallow chrome scan first. A resolved main placement returns without traversing deep content;
only a no-match scan continues far enough to confirm a non-main renderer surface before hiding.
Unavailable or incomplete scans preserve the last confirmed state.

## Upgrade boundary

The official Codex bundle is read-only. The plugin's app, data, and LaunchAgent live under the user
home directory. A Codex upgrade changes host discovery input, not the companion installation. A
plugin upgrade replaces the payload through a temporary app and atomic rename before restarting the
LaunchAgent.

## Binary provenance

The marketplace companion is promoted from a successful GitHub Actions artifact rather than built
separately for the repository commit. `assets/PROVENANCE.json` binds that payload to its source
commit, workflow run, artifact digest, archive digest, executable SHA-256, and code-directory hash.
The repository validator checks both the executable hash and that no plugin source changed between
the recorded source commit and the marketplace snapshot, apart from the promoted app and provenance
record.

## Safety properties

- Exact install and uninstall paths are validated before destructive operations.
- App-server reads are coalesced and recover after stalled or exited transports.
- Stale quota data dims after two minutes and hides after five minutes.
- Ambiguous anchors, invalid windows, non-foreground host state, and completed non-main surfaces
  hide the overlay.
- The overlay does not take keyboard focus or replace native Codex controls.
