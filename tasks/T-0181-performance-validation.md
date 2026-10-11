---
id: T-0181
title: Validate exported performance report consistency
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0180]
touch:
  - tools/performance_validation.py
  - tools/tests/test_performance_validation.py
  - tasks/T-0181-performance-validation.md
revision: 1
---

## Goal
Validate exported performance report consistency. Owner requests five further tasks possible before P2 without new human results.

## Context
T-0165/T-0169: engine render diagnostics are not physical latency or an NFR/FUN verdict. Original Astra Q3 and T-0139 remain human measurements. AGENTS.md requires bounded scope, public behavior tests and fresh review.

## Current state
T-0180 contract and existing tools/performance_report.py build_report are merged; new validator/tests absent.

## Specification
Implement validate_report(document: object) -> dict and parse_report(text: str) -> dict per contract. Validate exact report schema/identity/window values and recompute summary with existing build_report. Reject duplicates/nonfinite values/booleans/wrong summaries. Return independent deep copy. Do not alter existing parser or tests.

## Out of scope
No runtime, existing parser/tests, schema, APK, save/content, game visuals, dependencies, secrets or P2/gate changes. No invented device observations.

## Tests
Existing synthetic valid records accepted, duplicate nested keys and extra/missing fields rejected, boolean schema/counts/measurements rejected, operator identity/hash validation, tampered each summary field rejected, bad windows propagated, no mutation/aliasing, Unicode device, unavailable stats and zero values preserved.

## Acceptance
Specified behavior/tests; full make check, scope/count, fresh independent review and final-head successful12jobCI before sequential squash merge.

## Outcome
Added strict exported-report validation with recomputed summaries, duplicate-key rejection and independent normalized copies. 43 focused tests pass; removing summary comparison in memory fails nine tests, tracked source untouched. Full check: 275 GUT / 13332 assertions, 311 pipeline, 329 tools, 65 levels. Scope three files; count 518 vs 507. Fresh independent review APPROVE on 829ea61d8a02ec28b453e4b989607d653c3a9afc. Final-head successful 12-job CI required before merge. Existing parser, runtime and human gates unchanged.
