# SDD ledger — plan: docs/superpowers/plans/2026-08-23-windows-compatibility-v033.md

Preflight scan:

| Tasks/interfaces | Finding | Ruling |
| --- | --- | --- |
| 1 → 2 | Task 1 creates decision/state contracts consumed by Task 2. | Execute Task 1 first. |
| 1 → 3 | Task 3 consumes explicit failure codes and persisted preferences from Task 1. | Execute Task 1 first. |
| 2 → 3 | Task 3 consumes adaptive resolver failure/success outcomes. | Execute Task 2 before Task 3. |
| 3 → 4 | Tray/control actions consume safe-dock preferences and runtime status. | Execute Task 3 before Task 4. |
| 4 → 5 | Setup health UI consumes runtime state and catalog. | Execute Task 4 before Task 5. |
| 5 → 6 | Real-device validation requires packaged runtime. | Execute Task 5 before Task 6. |

Ruling: The approved plan includes one public release but has sequential code dependencies; tasks will be implemented and reviewed serially. The cost is less parallel throughput, offset by avoiding incompatible cross-task interfaces.

Task 1: fix round 1/5 (2 addressed, 1 new overflow finding; commits 6fc4cc8..068d837)
Task 1: fix round 2/5 (overflow finding addressed; commits 068d837..c30e49b)
Task 1: complete (commits 0b12e88..c30e49b, review clean)
Task 2: fix round 1/5 (runtime observation, catalog bounds, and InvalidCatalog propagation addressed; commits a4738d9..c4c75cd)
Task 2: complete (commits c30e49b..c4c75cd, review clean)
Task 3: Ruling: the submitted core-only slice is not task completion because the approved plan requires coordinator integration, safe-dock rendering, drag snapping, and preference wiring. Continue Task 3 in the same worktree; cost is one additional integration pass before review.
Task 3: fix round 2 (UIA `COMException` containment and production locator composition coverage; focused 7/7, Windows 101/101, solution Core 54/54 + Installer 80/80 + Windows 101/101; commit ca36ffb).
Task 3: complete (commits c4c75cd..ca36ffb, high-DPI/caption acquisition review clean).
Task 4: initial implementation (signed P-256 bounded catalog validation, atomic cache, local state-aware control/tray actions, and user-initiated redacted ZIP export; focused 6/6, Core 54/54 + Windows 107/107 + Installer 80/80, commit 8266bac).
Task 4: fix round 1 (304 refreshes `UpdatedAt` atomically while preserving cache data/ETag; ZIP parser enforces one cumulative uncompressed `MaximumPackBytes` budget; focused 8/8, full suite Core 54/54 + Windows 109/109 + Installer 80/80, commit 4ade14e).
Task 4: complete (commits ca36ffb..4ade14e, security/reliability review clean).
Task 5: automated integration evidence recorded in docs/validation/windows-v0.3.3-task-5-automated.md (TDD red: missing installer/runtime contracts; green: Installer 83/83, Windows 111/111; full solution Core 54/54 + Installer 83/83 + Windows 111/111; hook/payload checks and diff check passed). The v0.3.3 formal setup plan stays explicitly non-publishable and gated for Task 6 real-device evidence; no device-validation claim was made.
Task 5: fix round 1 (wired signed cache composition into the production scanner/host, contained cache failures, added runtime-state installer health wait, and corrected v0.3.3 status labels; commit 05ad105).
Task 5: fix rounds 2–3 (malformed manifest field/root types retain packaged fallback and background updater; Windows 119/119, Installer 86/86, Core 54/54; commits b5d35ff..a8d8000).
Task 5: complete (commits 4ade14e..a8d8000, final runtime/install integration review clean).
Task 6: automated fixture matrix added with privacy-safe wide/narrow/right-pane samples, 100/125/150/200% physical DPI transforms, English/Simplified-Chinese semantic labels, and every unrecognised case exercising safe-dock fallback when data and host geometry exist. TDD red: missing matrix contract, then insufficient unrecognised marker mutation; green: focused 2/2. Full solution: Core 54/54 + Installer 86/86 + Windows 121/121; payload/hook/public-boundary/diff checks passed. `build-windows-v033-setup.ps1 -PlanOnly` remains `realDeviceValidated: false` / `publishableInstaller: false`; `verify-windows-v033-setup.ps1` stopped at the expected real-device-evidence gate. Real-device evidence remains required and no device claim was made.
