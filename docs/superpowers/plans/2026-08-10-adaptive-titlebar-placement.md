# Adaptive Titlebar Placement Implementation Plan

Date: 2026-08-10
Target: v0.2.3

## 1. Reproduce and measure

- Capture the overlap at an intermediate right-pane width.
- Record the Codex window, divider, indicator, native controls, and current diagnostic frames.
- Confirm whether the preferred control is absent from the scanned AX region.

## 2. Specify regressions first

- Test the horizontal scan reach left of the window midpoint.
- Test exclusion below the 46-point titlebar.
- Test exclusion of degenerate 1-point content frames clipped to the fullscreen top edge.
- Test geometry eligibility before label collection and collision re-evaluation when an obstacle
  appears without moving the semantic anchor.
- Test nearest-free-slot resolution and static-title barriers.
- Test immediate right-side fallback when no complete frame remains.
- Test resolved fallback replacing stale cache while unresolved scans retain the last valid frame.

## 3. Implement the resolver

- Collect titlebar buttons and static text as occupied frames.
- Keep semantic anchor selection limited to buttons.
- Resolve the preferred frame, scan left for the nearest complete free slot, then use fallback.
- Preserve existing layout spacing, fallback coordinates, and 0.1-second refresh cadence.

## 4. Validate locally

- Run focused resolver tests and the complete Swift suite.
- Build and sign the companion, run repository/control/signing/data checks, and install locally.
- Drag the right pane through the reproduced widths and capture both adaptive states.
- Obtain user confirmation before GitHub publication.

## 5. Publish with provenance

- Set the synchronized manifest and bundle version to v0.2.3.
- Update README, Chinese README, architecture, install, agent install, privacy, troubleshooting,
  changelog, diagrams, screenshots, and release notes.
- Push the source commit and wait for successful GitHub Actions output.
- Promote the exact CI artifact and provenance, then merge to `main` after validation.
- Publish the v0.2.3 ZIP, checksums, and provenance as a GitHub Release.
- Reinstall the formal release and verify version, signature, runtime, and adaptive placement.
