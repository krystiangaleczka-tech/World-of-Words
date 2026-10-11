---
id: T-0161
title: Render faithful offline level and word review HTML
epic: E08
type: feat
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0160]
touch:
  - pipeline/src/wordgame_pipeline/review_html.py
  - pipeline/tests/test_review_html.py
  - tasks/T-0161-curator-review-html.md
revision: 1
---

## Goal
Render faithful offline level and word review HTML. Owner requested five more tasks before the pending P2 human gate.

## Current state
build_report provides sorted required-word annotations and input receipts. Shipped placements use w/x/y/dir and grid w/h. New renderer/test do not exist.

## Specification
Add render_review(report: dict, levels: Mapping[int, dict]) -> str. Deterministic standalone UTF-8 HTML with Polish curator copy, responsive inline CSS, slot links, all level grids/wheel letters/required annotations, coverage and source hashes. Escape all data. No scripts, network/resources, timestamps or writes. Match exact slots/IDs/required order against provided levels; reject mismatches, invalid direction/out-of-bounds/conflicting grid cells. Show proposed/unknown/missing explicitly; bonus words are not rated. This is QA tooling, not final game visuals.

## Tests
Test actual65/103 rendering, faithful horizontal/vertical/intersecting letters and repeated wheel tiles, blanks, slot/ID/word mismatch rejection, malformed geometry, escaped hostile rationale/reviewer/ID, stable output/nonmutation, embedded CSS/no scripts/external resources.

## Acceptance
Only authorized touch files; full make check, scope/count, independent fresh review
and final-head green CI before squash merge. No human review or phase result invented.

## Outcome
Faithful standalone HTML passes 11 focused cases and independent all65-cell,
wheel and annotation comparisons. Final-source full make check passes: 247 GUT /
13049 assertions, 286 pipeline, 142 tools, 65 levels. Scope three files; count425
vs421. Fresh review approved bbb94981a9742cc14c3f51eb853389eff3ad477a after
summary escaping correction. Final-head green CI required before squash merge.
