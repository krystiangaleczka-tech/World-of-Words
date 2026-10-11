---
id: T-0162
title: Export an editable required-word review worksheet
epic: E08
type: feat
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0161]
touch:
  - pipeline/src/wordgame_pipeline/review_worksheet.py
  - pipeline/tests/test_review_worksheet.py
  - tasks/T-0162-curator-review-worksheet.md
revision: 1
---

## Goal
Export an editable required-word review worksheet. Owner requested five more tasks before the pending P2 human gate.

## Current state
build_report annotations preserve proposed/reviewed/missing states; WordReview CSV header is frozen. New worksheet/test do not exist.

## Specification
Add export_worksheet(report: dict) -> str. Exact familiarity CSV header, LF, Unicode-sorted unique required forms, quoted fields and original existing annotations. Never promote proposals. Missing annotations become blank-band proposed/unassigned with rationale Awaiting curator review. Repeated required annotations must agree or fail ValueError. No files/network or report mutation. Output is a draft for explicit per-word curator editing, not a human decision.

## Tests
Test actual103 roundtrip through load_catalog/native tiers, all proposal states retained, reviewed/unknown/quoted comma/newline/diacritics preserved, sorted unique repeated words, inconsistent repeated judgment rejection, missing draft defaults, stable output/nonmutation.

## Acceptance
Only authorized touch files; full make check, scope/count, independent fresh review
and final-head green CI before squash merge. No human review or phase result invented.

## Outcome
Draft export passes six focused cases including actual103 native roundtrip;
annotations and proposal states retained. Full make check: 247 GUT / 13049
assertions, 292 pipeline, 142 tools, 65 levels. Scope three files; count428
vs425. Fresh independent review approved 3c07afd3654f51b788904aa1c9c8764fbfe38c0f.
Final-head green CI required before squash merge.
