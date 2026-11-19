---
id: T-0490
title: Build a 10,000-slot Polish campaign for editorial and device QA
epic: E22
type: content
area: content.pl
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0395, T-0396]
touch:
  - pipeline/src/wordgame_pipeline/qa_campaign.py
  - pipeline/tests/test_qa_campaign.py
  - .github/workflows/qa-pl-campaign.yml
revision: 1
---

## Goal

Generate a downloadable Polish QA campaign with exactly 10,000 numbered slots.
Use the current 65 shipped levels and the authored 66 through 200 draft as the
front of the campaign. Produce a word review worksheet and validation evidence.

## Current state

T-0395 supports 30,000 campaign slots in the runtime schema and pack readers.
T-0396 documents the wheel supply limit of the compact P1 evidence. A separate
full-source preflight from the November 2026 SJP snapshot found 30,751 wheel
signatures with at least two potential answers. PR #289 contains the proposed
slots 66 through 200. The canonical repository pin remains the September source
used by the existing P1 validation receipt.

## Specification

- Use the exact November archive already analyzed, with the existing source
  and morphology/frequency verification, in an isolated build root.
- Preserve the bytes of the existing 1 through 65 pack. Validate the authored
  66 through 200 draft against the full tiers and derive its full bonus sets.
  Extend the campaign with distinct wheels, connected portrait grids, two or
  more crossword answers and a 100-slot gap between repeated crossword answers.
- Emit canonical packs and a manifest. Exercise the schema and the pack reader
  including slot 10,000, and validate every new level with the existing rule
  and geometry checks. Produce word review and per-slot evidence for editors.
- Use an isolated GitHub Actions QA build while the local environment is
  unavailable. Limit the workflow to this branch or an explicit dispatch.
  Keep the existing tracked campaign, source pin and release locks intact.

## Tests

Use a small deterministic wheel fixture to cover a spacing-safe selection,
deferred wheels and preservation of the input inventory. In the real run,
verify all 10,000 identities and hashes, literal preservation of the first pack,
complete bonus lists for appended slots and global wheel and answer spacing.

## Acceptance

Publish a CI artifact for the draft campaign, with the resource manifest,
technical QA results and editorial worksheet. The production difficulty
curve, human QA sign-off, release locks and public rollout remain T-0408 and
T-0484 through T-0489 responsibilities.
