---
id: T-0155
title: Define offline lexical familiarity review and freeze five follow-ups
epic: E08
type: docs
area: content.pl
risk: low
executor: sol
think: high
ui: none
status: done
depends_on: [T-0154, T-0131]
touch:
  - docs/qa/T-0155-familiarity-contract.md
  - tasks/T-015[5-9]-*.md
revision: 1
---

## Goal
Freeze a small offline review workflow for familiar required answers, independent
of source eligibility, grid size and runtime difficulty. Owner requested five
continued tasks; this wave stays before P2 and needs no model API credentials.

## Current state
- T-0152 curates 65 slots; its QA report requests lexical familiarity bands before
  expanding content. Runtime difficulty remains 0.0.
- p1.check performs read-only deterministic replay; compact source records list
  eligible native forms and tiers, not lexical familiarity.
- No familiarity catalog/parser/report exists; T-0150 is still owner-local.

## Specification
1. Specify CSV fields word, band, status, reviewer, rationale; native non-banned
   membership is mandatory. Bands 1..5 describe familiarity, empty means unknown.
2. Status proposed cannot qualify for an early-answer gate. Reviewed must name
   its curator and an explicit band. File validation cannot authenticate a review.
3. Current catalog will contain proposals, not invented Chris decisions or
   corpus-frequency claims. Later long familiar words may receive easy proposals;
   no automatic mapping from wheel/slot complexity to familiarity.
4. Freeze T-0156..T-0159 exact contracts, allowlists and tests in separate taskfiles.
5. The future report uses required answers only; hard valid optional bonuses stay
   eligible. The gate is opt-in, does not change p1.build/check or game data.
6. Retain all source pins, runtime formats, approved S26 evidence and phase gates.

## Tests
No runtime tests for documentation. Verify cited current APIs and all task metadata,
scopes/dependencies; full make check and fresh independent review before green CI
and squash merge. ROADMAP and original Astra report remain unchanged.

## Acceptance
Five bounded tasks have frozen specifications and cannot confuse proposals,
source validity, editorial familiarity, runtime difficulty or human phase approval.

## Outcome
Full make check passed: 247 GUT / 13049 assertions, 201 pipeline, 142 tools,
65 validated levels. Metadata/scope/count pass: 107 tasks, six documentation/task
files, 397 tests unchanged. Fresh independent review approved
6c85f293601d30760280b6ffbebb3e4bc25a41f3 without blockers, verifying existing
APIs, task dependencies, proposal/review separation and unchanged bonus policy.
Final-head remote CI remains required before merge.
