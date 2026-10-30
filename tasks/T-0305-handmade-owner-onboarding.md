---
id: T-0305
title: Prepare human approval of existing handmade Polish onboarding slots 1 to 15
epic: E22
type: content
area: content.pl
risk: medium
executor: human
think: none
ui: high
status: blocked
depends_on: [T-0304, T-0203]
touch:
  - docs/qa/T-0305-onboarding-1-15-review.csv
  - docs/qa/T-0305-onboarding-review-guide.md
  - tasks/T-0305-handmade-owner-onboarding.md
revision: 1
---

## Goal
Review the already authored 1–15 onboarding levels from
`pipeline/handmade/pl/opening.yaml` with a full owner/device verdict.
Do not invent human acceptance or replace the established P1 prototype.

## Scope
Create an exact fifteen-row QA/authoring sheet with wheel, answers, bonuses,
grid dimensions and empty owner decision columns. Instructions require review
of teaching sequence, Polish vocabulary, COMPACT readability and swipe feel.

## Blockers
T-0304 lexical owner review is not complete. Chris must actually play and
approve all fifteen levels or request explicit scoped changes to handmade
YAML followed by rebuild and validation. Status stays `blocked`.
No game/content, override, released-slot or config writes.
