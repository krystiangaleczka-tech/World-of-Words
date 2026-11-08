---
id: T-0299
title: Campaign duplicate and seed diversity gate
epic: E22
type: feat
area: pipeline.dedupe
risk: medium
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0298]
touch:
  - pipeline/src/wordgame_pipeline/dedupe/campaign.py
  - pipeline/tests/dedupe/test_campaign.py
  - tasks/T-0299-campaign-diversity-gate.md
revision: 1
---

## Goal
Reapply authoritative T-0356 duplicate auditing to actual P2 campaign slot
records. Require an explicit seed word per slot and detect same letter
multiset, selected-word Jaccard, crossword spacing <100 and seed spacing K.

## Scope and tests
Pure audit returns precise conflicts and an explicit hard-fail gate.
No source word is banned/selected/removed. No generated bonus counts as a
crossword repetition. Reject gaps, duplicates, missing seeds and bad identities.
Use T-0356 authoritative policy; tests verify order independence, rule
conflicts, clean campaigns and malformed seeds.

## Blockers
Roadmap T-0298, human T-0304 and approved thresholds remain outstanding.
This is a draft code change and not production activation. Existing P1 content,
source words, `game/content/` and configurations are untouched.
Full CI and independent fresh review needed.
