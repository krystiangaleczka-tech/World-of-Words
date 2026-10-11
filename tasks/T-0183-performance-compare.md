---
id: T-0183
title: Compare diagnostic captures without inferred verdicts
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0182]
touch:
  - tools/performance_compare.py
  - tools/tests/test_performance_compare.py
  - tasks/T-0183-performance-compare.md
revision: 1
---

## Goal
Compare diagnostic captures without inferred verdicts. Owner requests five further tasks possible before P2 without new human results.

## Context
T-0165/T-0169: engine render diagnostics are not physical latency or an NFR/FUN verdict. Original Astra Q3 and T-0139 remain human measurements. AGENTS.md requires bounded scope, public behavior tests and fresh review.

## Current state
T-0181 validator and T-0182 renderer merged; compare module/tests absent.

## Specification
Implement compare_reports(baseline: dict, candidate: dict) -> dict and render_comparison(baseline: dict, candidate: dict) -> str per contract. Preserve validated deep copies, sorted exact metadata differences and eight summary measure deltas plus window_count. Deltas candidate-baseline; unavailable maxima become null. Report different coverage/context, not causal conclusions.

## Out of scope
No runtime, existing parser/tests, schema, APK, save/content, game visuals, dependencies, secrets or P2/gate changes. No invented device observations.

## Tests
Positive/negative/zero deltas, unavailable one/both sides, unequal counts/contexts, ordered metadata changes, same source/hash, deep independence, original order/inputs, escaped Markdown device, invalid either report rejection, no window alignment, no winner/regression/gate verdict.

## Acceptance
Specified behavior/tests; full make check, scope/count, fresh independent review and final-head successful12jobCI before sequential squash merge.

## Outcome
Added descriptive comparison with independent full captures, exact metadata differences, nine candidate-minus-baseline deltas and null unavailable maxima. Genuine negative -1 differences remain numeric. Twelve focused tests pass; in-memory subtraction-direction mutation fails two tests without disk edits. Full check: 275 GUT / 13332 assertions, 311 pipeline, 348 tools, 65 levels. Scope three files; count 531 vs 524. Fresh independent review APPROVE on 50f37b23809da3a104a8a0415efb8cb54988bd8d. Final-head successful 12-job CI required before merge; no causal or human acceptance verdict.
