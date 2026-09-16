# Documentation refresh — 2026-09-15

Scope: current working 0.4.0 candidate, with published-version references retained from the local
release catalog. No release, installation replacement or Windows device test was performed here.

## Coverage

- English and Simplified Chinese README: matching current feature/interaction tables, candidate
  status, position fallback, detail lock, settings, Bank urgency, diagnostics and current imagery.
- Current feature inventory and design contract; architecture, privacy, installation/agent guidance,
  troubleshooting, plugin README, contribution guide and candidate release notes.
- Historical design/plan and version-specific Windows handoff records marked with explicit scope;
  original dated content and published release records retained.
- Updated placement schematic; replaced active README GUI references with eight native AppKit
  renders (two card languages/themes plus position/settings menus).

## Evidence

- Full Swift suite: **332 tests, 0 failures** after adding optional documentation-menu export.
- Visual fixture suite: **15 tests, 0 failures**, generated from actual AppKit views with fixed
  demonstration data and 0.4.0 badge. All eight delivered PNGs were visually inspected.
- Local Markdown/HTML image references were checked for existence; SVGs parsed as XML.
- `git diff --check` passed.

## Limits and discrepancies documented

- Long English labels can clip in the current fixed-width card/menu. Native renders preserve that
  behavior; no image retouching or product-layout fix was bundled into this documentation task.
- Natural macOS detail viewport is **at least** eight rows and grows with content; it is not always
  exactly eight rows. Manual minimum and screen/height caps are documented separately.
- Global mouse-down observers are used for outside dismissal, so the previous blanket privacy
  statement denying global mouse events was corrected.
- Local dirty builds are not promoted CI releases. Catalog platform tags and governing Release
  Please tag conventions still require reconciliation before publication.
- Current Windows source is described without claiming a new Windows release or device acceptance.
- No live Codex window screenshot is claimed. GUI examples are native-control fixtures with no
  real account data; historical PNGs remain only for version-scoped references.
