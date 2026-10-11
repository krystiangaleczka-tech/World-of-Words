---
id: T-0184
title: Expose readable performance reports and comparisons
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0183]
touch:
  - tools/performance_cli.py
  - tools/tests/test_performance_cli.py
  - docs/qa/T-0184-performance-analysis-usage.md
  - tasks/T-0184-performance-cli.md
revision: 1
---

## Goal
Expose readable performance reports and comparisons. Owner requests five further tasks possible before P2 without new human results.

## Context
T-0165/T-0169: engine render diagnostics are not physical latency or an NFR/FUN verdict. Original Astra Q3 and T-0139 remain human measurements. AGENTS.md requires bounded scope, public behavior tests and fresh review.

## Current state
T-0181..T-0183 validators/renderers/comparison functions merged; CLI/tests/usage absent.

## Specification
Implement main(argv: list[str] | None = None) -> int: report PATH; compare BASELINE CANDIDATE --format json|markdown default markdown. UTF8 readonly/stdout, input errors stderr exit1, usage argparse exit2, no partial output/writes. Document existing raw capture -> JSON -> readable/comparison chain and human conditions.

## Out of scope
No runtime, existing parser/tests, schema, APK, save/content, game visuals, dependencies, secrets or P2/gate changes. No invented device observations.

## Tests
Subprocess real entrypoint: both report/compare formats, Unicode, malformed/duplicate/tampered JSON, missing/encoding/directory files, argument errors, stdout/stderr/status, deterministic output and input bytes unchanged; full checks/review/CI.

## Acceptance
Specified behavior/tests; full make check, scope/count, fresh independent review and final-head successful12jobCI before sequential squash merge.

## Outcome
Added read-only report/compare commands and actual capture analysis guidance. Report renders Markdown; comparison supports JSON/Markdown as frozen interface specifies. 22 CLI subprocess cases and all 84 wave cases pass. Full check: 275 GUT / 13332 assertions, 311 pipeline, 370 tools, 65 levels. Scope four files; count 536 vs 531. Fresh independent review APPROVE on e9f49578b4339f9891fa1ad568cbbe37ace288a3. Final-head successful 12-job CI required before merge. Existing runtime/parser and human gates unchanged; no new phone observations claimed.
