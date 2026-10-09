---
id: T-0129
title: Review initial Polish campaign word candidates and seed overrides
epic: E08
type: content
area: content.pl
risk: medium
executor: human
think: none
ui: none
status: done
depends_on: [T-0123]
touch:
  - pipeline/overrides/pl.csv
  - pipeline/reviews/pl/T-0129-*
  - docs/qa/T-0129-word-review.md
  - tasks/T-0129-pl-word-review.md
revision: 1
---

## Goal
Record a review of 300 real level-word candidates and seed auditable exceptions.
Chris delegated preparation/execution of this content task in his request to do the
next five tasks. Author decisions honestly as codex; do not claim a Chris playtest.

## Current state
T-0123 is done. overrides/pl.csv contains only its required header. Native pinned
T-0125 grid/T-0123 tiers exist locally; automatic export selects wheel size then ID.
The source pool contains many short specialist, archaic and fragment forms.

## Specification
1. Review the first 300 unique selected crossword words encountered in automatic
   candidate order (wheel size then candidate ID, excluding eight-tile wheels).
   Commit a ranked review CSV with previous tier, decision, reason and source
   frequency context; commit native tier/grid hashes and deterministic selection
   method in a provenance JSON. This targets actual early campaign proposals.
2. Keep common ordinary words. Downgrade niche/archaic/context-dependent forms to
   bonus_ok; ban offensive words and foreign-name fragments. Every changed word
   already exists in the pinned source, never invent entries or promote words.
   Preserve Chris's accepted BABA/HAZARD/KASYNO/POKER preference.
3. Overrides use word,tier,reason,date,by, valid ISO date and codex attribution.
   Record all 300 decisions and rationale; only exceptions become overrides.
4. Rebuild the actual tiers stage, report counts/unmatched decisions/hash. Downstream
   ignored candidate/grid/validate artifacts become stale and are rebuilt in T-0131.
   No code/schema/source-pin/rule changes or new shipped content.

## Tests
Existing pipeline tests plus full make check. On actual native tiers, verify all
reviewed words exist, every override matches, kept words stay level_ok, downgraded
forms are bonus_ok, bans are banned and no unmatched overrides remain. No new tests
that merely mirror CSV rows. Fresh reviewer checks the decisions and audit trail.

## Acceptance
Complete review CSV/provenance, native tier evidence, make check, scope/task lint,
fresh independent review and all CI. Later human play QA (T-0140) remains required.

## Rollback
Revert override/review files, regenerate ignored tiers and downstream artifacts.
