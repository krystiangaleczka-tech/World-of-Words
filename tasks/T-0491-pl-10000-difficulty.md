---
id: T-0491
title: Order the Polish QA campaign into five difficulty bands
epic: E22
type: content
area: content.pl
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0355, T-0490]
touch:
  - pipeline/config/qa-campaign-scoring.json
  - pipeline/src/wordgame_pipeline/qa_campaign.py
  - pipeline/src/wordgame_pipeline/sequence/qa_progression.py
  - pipeline/tests/sequence/test_qa_progression.py
  - .github/workflows/qa-pl-campaign.yml
revision: 1
---

## Goal

Use the existing 10,000 Polish QA crossword designs to produce a campaign ordered
by difficulty, with five successive bands and a traceable estimate for each moved slot.

## Current state

T-0490 is in draft PR #322 and has produced the candidate pack. The current preview
cycles through wheel sizes and answer counts and writes a zero difficulty field.
T-0355 is merged and supplies the configured scorer used with the T-0354 extractor.
Execute this task against the verified T-0490 parent and keep the PR stacked.

## Specification

- Apply explicit QA weights to existing crossword features and exact-form ARF from
  the pinned tier artifact. Keep scoring and calibration outside the runtime.
- Preserve the literal first 65 levels and the crossword, letters and bonus data
  for every other level. Assign the remaining slots to five successive measured
  difficulty ranges. Store each band's lower score in the runtime difficulty field
  and retain individual estimates and original slot numbers in the QA worksheet.
- Within a band, greedily schedule repeats early enough to allow the 100-slot answer
  gap. Start the revised sequence at the lowest eligible estimate and reserve the
  highest estimate for the final slot. Report a blocked slot if this ordering pass
  cannot complete the schedule.
- Increment the QA content version and rebuild hashes, pack read-back evidence and
  the internal Android artifact. The tracked campaign and release locks stay intact.

## Tests

Test range ordering, endpoint selection, deterministic output and a repeated answer
that cannot fit at the requested gap. Run the full build on the pinned 10,000-level
input and verify the layout inventory, 65-slot baseline, sustained answer spacing,
and representative first and final slots through the exported Godot package.

## Acceptance

Publish a test APK and content artifact with the five ranges and per-slot scores.
Keep the provisional pacing distinct from production calibration and editorial QA.
