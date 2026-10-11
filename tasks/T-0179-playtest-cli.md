---
id: T-0179
title: Expose offline playtest worksheet and report commands
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0178]
touch:
  - tools/playtest_cli.py
  - tools/tests/test_playtest_cli.py
  - docs/qa/T-0179-outsider-playtest-capture.md
  - tasks/T-0179-playtest-cli.md
revision: 1
---

## Goal
Expose offline playtest worksheet and report commands. Owner requested five further tasks; prepare real P1 observations while human phase gates remain pending.

## Context
T-0154 baseline: five outsiders, at least 20 active minutes, no instructions/help, same build, isolated slot-1 campaign, answers/overlays hidden. Astra T-0142 separates deterministic checks from human device/FUN evidence. AGENTS.md requires public behavior tests, bounded scope and independent review.

## Current state
T-0176..T-0178 provide worksheet rendering, parsing and summary rendering. CLI, tests and usage note do not exist.

## Specification
Implement main(argv: list[str] | None = None) -> int: template; validate PATH; report PATH --format json|markdown (default markdown). Stdout only, read inputs UTF-8, deterministic errors to stderr and exit1 for input errors, argparse exit2 for usage. Do not write files or authenticate metadata. Document collection protocol, missing evidence and explicit remaining human gates.

## Out of scope
No runtime/save/content changes, personal campaign resets, automatic human judgments, simulated phone results, participant names, new dependencies, secrets or P2 entry.

## Tests
Subprocess command end-to-end: blank template roundtrip, validation success means format only, both reports, Unicode, malformed/duplicate JSON, file read errors, argument errors, stdout/stderr/exit statuses, unchanged input bytes. Full checks/review/CI.

## Acceptance
All specified behavior and tests. Full make check, scope/count, fresh independent review and final-head 12-job successful CI before sequential squash merge. Helpers never close T-0139/T-0140/T-0141/T-0143.

## Outcome
Exposed template/validate/report commands and operator capture guidance; no input writes, inferred observations or human gate verdict. 23 CLI subprocess tests and all103wave focused cases pass. Full check:275GUT/13332assertions,311pipeline,286tools,65levels. Scope4files/count507vs501. Fresh independent review APPROVE on a81455252e5dbe0084cd732caaae6d6b44234cbf. Blank worksheet and missing-evidence reports generated outside repo using CLI, not claimed real sessions. Final-head successful12jobCI required before squash merge.
