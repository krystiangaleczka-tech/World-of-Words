---
id: T-0154
title: Publish the current playtest baseline and owner device approval
epic: E09
type: docs
area: docs
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0151, T-0152, T-0153]
touch:
  - docs/qa/T-0154-playtest-baseline.md
  - docs/qa/T-0154-level-inventory.csv
  - tasks/T-0154-playtest-baseline.md
revision: 1
---

## Goal
Provide a repository-owned current baseline for further human playtests. Older
local forms describe content version 1 and a runtime before the diagnostic fix.
Record Chris's explicit S26 Ultra approval without requiring him to repeat it.

## Context
- `docs/TESTING.md#reference-devices`: A15 and S26 Ultra have distinct purposes.
- `docs/qa/T-0149-audit-followup.md`: technical fixes retain separate phase gates.
- Owner confirmed and approved the reported S26 Ultra tests on 2026-10-11 and
  requested continued tasks; T-0150 remains local on his computer until pushed.

## Current state
- Merged T-0151 isolates non-current diagnostic sessions from campaign Save.
- T-0152 ships content version 2: 65 authored slots, 103 unique required words,
  1697 bonus entries, maximum seven tiles, final PARASOL/ROSA/PAS.
- T-0153 checks shipped-content screen/navigation/save behavior automatically.
- Older local T-0139..T-0143 forms pin 68d7ccd and version-1 slot inventory.
- The new QA baseline and inventory files do not exist.

## Specification
1. Record merged task/CI receipts, exact content pack hash, and current APK
   download identity with verified artifact expiry. Distinguish ZIP digest from
   APK digest and historical S26 device APK from the CI build.
2. Record owner approval of reported S26 Ultra T-0151/T-0152 observations. Keep
   original Astra report and historical QA reports unchanged. Do not claim a
   new device run, all-level manual completion, A15 measurements or FUN GATE.
3. Describe campaign persistence vs non-current diagnostic session behavior,
   final-slot resume, and current familiar-word inventory. Preserve existing
   save/installation guidance; perform no device, signing or secret actions.
4. Publish a CSV derived from the committed pack with one row per slot and
   letters, dimensions, required words and bonus count. Leave observation/result
   fields empty; mark answer inventory as reviewer-only, not outsider instructions.
5. Provide compact protocols for manual content/feel and five outside players,
   retaining existing ≥20-minute unassisted requirement and task dependencies.
   Supersede stale local forms as current baseline without fabricating results.

## Tests
No new runtime tests for documentation. Independently compare every CSV row,
counts/hash and cited receipts against committed content/GitHub. Verify blank
result fields and bounded device/approval claims. Run full make check and task,
scope/count checks; fresh independent review and green remote CI before merge.

## Acceptance
The current baseline is usable without confusing old words/builds or asking for
approval already supplied. Human evidence remains separate from automated tests.

## Outcome
Fresh independent review approved 90c3d8d4c3bc87d8b45637fd29faaa91efbcc0de
without blockers. It independently verified every CSV row/count/hash, blank
observation fields, all three merged PRs and their 12-green-job CI runs, and
the APK artifact's exact source, archive digest and expiry. Full make check
passed: 247 GUT / 13049 assertions, 201 pipeline, 142 tools and 65 levels.
Metadata/scope/count pass: 102 tasks, three files, 397 tests unchanged.
Owner-approved S26 evidence is recorded without rewriting historical reports
or inventing additional device/phase results. Final-head CI is required to merge.
