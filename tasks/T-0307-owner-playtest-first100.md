---
id: T-0307
title: Capture owner device playtest of the first 100 verified Polish levels
epic: E22
type: content
area: content.pl
risk: medium
executor: human
think: none
ui: none
status: blocked
depends_on: [T-0306, T-0294]
touch:
  - docs/qa/T-0307-first-100-playtest.csv
  - docs/qa/T-0307-playtest-protocol.md
  - tasks/T-0307-owner-playtest-first100.md
revision: 1
---

## Goal
Produce owner-test evidence on the first hundred playable campaign slots.
Preparation yields a deterministic slot checklist (65 existing + 35 proposed)
and **no fake playtest data**.

## Testing
Record real Android device build, exact slot, tap/swipe/word and completion
observations for all 100 levels. Review flags feed human overrides and a
deterministic rebuild; do not mark `done` before all 100 are playable and tested.

## Blockers
T-0306 is still a candidate-only draft PR #289; 66–100 are not live.
Onboarding/editorial approvals, T-0294 debug tooling and production export,
real device runs and QA retests are still required. This task remains
`blocked` and does not alter game/content, config or owner decisions.
