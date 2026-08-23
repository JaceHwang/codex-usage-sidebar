# SDD ledger — plan: docs/superpowers/plans/2026-08-23-v033-release-chain-remediation.md

Preflight scan:

| Tasks/interfaces | Finding | Ruling |
| --- | --- | --- |
| 1 → 2 | Task 1 creates the v0.3.3 profile and contract harness consumed by validation tests. | Execute Task 1 first. |
| 2 → 3 | Task 3 manifest/payload scripts require the exact validator and evidence contract from Task 2. | Execute Task 2 before Task 3. |
| 3 → 4 | Task 4 documents the actual command and boundaries produced by Task 3. | Execute Task 3 before Task 4. |
| Task 3 / existing v0.3.2 chain | v0.3.2 is the complete release pattern; v0.3.3 must not call it because its branch, evidence and version constraints are immutable. | Port the pattern with v0.3.3-specific scripts and tests; preserve all v0.3.2 files. |

Ruling: the Task 5 v0.3.3 setup placeholder is a root-cause release-chain defect, not a valid permanent evidence gate. This remediation keeps the formal release fail-closed for missing evidence and credentials but makes a complete future formal build possible. Cost if wrong: future release packaging could diverge from v0.3.2; task-scoped tests and review must detect it.

Task 1: fix round 1/5 (exact evidence/no-artifact and portable interpreter findings addressed; commit cd69a29).
Task 1: Ruling: the remaining reviewer finding that the builder must consume `v033_release_profiles.py` belongs to Task 3, which is the plan's only task permitted to replace the builder. Carry it as a mandatory Task 3 acceptance condition rather than violating task boundaries. Cost if wrong: a future builder could drift from the formal descriptor; Task 3 test/review must close it.
Task 1: complete (commits 932be43..cd69a29, profile/contract review clean except the ruled Task 3 dependency).
Task 2: fix round 1/5 (strict UTC-instant timestamp validation and independently green --evidence-only contract added; commit d1c57bb).
Task 2: complete (scoped re-review clean; full-chain red boundary is explicitly limited to zero-output source/branch validation until Task 3 replaces it).
Task 3: review round 1/5 found a formal-matrix mismatch that would make every v0.3.3 installer self-check fail, missing runtime binding for compatibility configuration, and no executable installer-level regression. Repair in progress; no release-chain completion claim before these are closed.
Task 3: fix round 2/5 closes the matrix, runtime-metadata, and executable installer-test findings (commit 314c86b); scoped re-review clean.
Task 3: complete (commits 708a3af and 314c86b; the v0.3.3 chain is implementable but formal production output remains intentionally unavailable without complete evidence and maintainer release inputs).
Task 4: added a focused release-chain documentation contract and observed it fail because the canonical v0.3.3 formal evidence handoff was absent. The required template, installation, and troubleshooting handoff now describe the canonical non-secret build inputs, unpublished-installer status, fail-closed formal preconditions, automatic selector/update recovery, default-redacted diagnostics, and automatic safe dock. Full shell contract and Windows solution tests pass; formal real-device validation remains unclaimed.
