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
status: ready
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
