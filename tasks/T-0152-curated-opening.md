---
id: T-0152
title: Curate the 65 Polish prototype levels by familiarity
epic: E08
type: content
area: content.pl
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0131]
touch:
  - pipeline/handmade/pl/opening.yaml
  - pipeline/config/p1-pl.json
  - pipeline/content-inputs/pl.json
  - pipeline/content-evidence/pl.json
  - pipeline/tests/test_p1_content.py
  - game/content/pl/manifest.json
  - game/content/pl/packs/c-0001-0065.json
  - docs/CONTENT.md
  - docs/qa/T-0152-curated-opening.md
  - tasks/T-0152-curated-opening.md
revision: 2
---

## Goal
Apply Chris's 2026-10-11 device feedback to exactly 65 unreleased prototype
slots, then export and install an Android debug build without losing his save.
Choose recognizable words rather than assuming short forms are easy.

## Context
- `docs/CONTENT.md#p1-deterministic-campaign-export-t-0127`: authored slots are preserved;
  source-backed complete bonus pools and 100-slot crossword spacing remain mandatory.
- Decision 0004: required answers are eligible lemmas/frequent forms; bonus words
  include every valid non-banned source form, not just easy answers.
- Direct owner request authorizes revising these unreleased slots; do not edit ROADMAP.

## Current state
- `pipeline/handmade/pl/opening.yaml` pins slots 1–15, including LAT, KUR, RYB and PSI.
- `pipeline/config/p1-pl.json` selects 65 slots at content version 1.
- `p1.build(root, content)` and `p1.check(root, content)` generate/replay native inputs.
- `load_handmade(root, index)` already supports authored slots beyond onboarding;
  exporter fills only unpinned slots automatically.
- No content lock exists for this privately sideloaded prototype.
- `test_real_campaign_rebuild_is_offline_readonly` expects 15 authored/50 automatic slots.

## Specification
1. Author all 65 slots using existing YAML and native pinned source tiers. Retain
   KOT, RAK, DOM/DYM, LATO, KOSA/OSA, WODA/DWA, KURA, RYBA and PIES near the start.
2. Remove unfamiliar inflections and niche words from required answers, including
   LAT, KUR, RYB, PSI, CŁA, DAŃ, HAL, JAJ and JAR. KOS is valid but not required here.
   Keep all source-valid optional bonuses, including the removed inflections.
3. Slots 16–30 use familiar four/five-letter everyday words; 31–45 introduce
   additional recognizable answers and five/six-letter wheels; 46–65 use familiar
   larger puzzles up to seven tiles. These are editorial prototype bands, not a
   runtime difficulty score or an implemented P2 lexical classifier.
4. Record KAJ as a valid regional/dialectal word, unsuitable as an early required
   answer. Native pinned input lacks KAJ: do not fabricate source membership or
   silently add it to generated bonuses. Document the source-coverage limitation.
5. Regenerate through the pipeline, raise content version to 2, retain exactly
   slots 1–65 and their IDs. No save schema, progression/economy or source-pin changes.
6. Document the editorial choices and future multi-band lexical classification
   requirement. Keep source eligibility separate from familiarity and puzzle size.
7. Use the existing Android build workflow and task/name/time metadata. Preserve
   the T-0151 diagnostics replay fix in the phone build via a separate integration
   worktree; do not include that code in this content branch. Back up and verify
   the phone save before installing. Do not change signing or platform settings.

## Tests
File: `pipeline/tests/test_p1_content.py`
- Existing offline replay/read-only, tampering, attribution and schema tests remain.
- Update real campaign assertion to 65 authored slots and unique required words.
- Add opening policy regression: recognizable retained answers, no flagged difficult
  forms across all 65, removed source-valid forms retained as bonuses, exactly 65
  levels/version 2, final PARASOL/ROSA/PAS puzzle, maximum seven tiles.
- Add authored-input mutation regression: changing the source YAML fails replay.
- Run `make check` and native generation plus offline deterministic check.

## Acceptance
Generated source-backed content and tests pass; draft PR records review concerns.
Phone launches the integrated APK with revised early/final levels and intact save.

## Out of scope
Thousands of levels, a full lexical scoring system, licensing a new dictionary,
released-slot changes, source ingestion extensions and save resets.

## Rollback
Revert this content revision and regenerate from the prior authored inputs.
Slots are unreleased; no save migration is required. Retain the exact device save
backup and previous APK for device rollback.

## Outcome
Fresh independent review approved f73f165af88aa5d6221ec0016a1964d38e616a86
against merged T-0151, without blockers, and verified complete bonuses against
all 450,122 native tier records. Native generation and read-only replay passed
with no generated-file changes. Combined make check passed: 244 GUT tests /
10791 assertions, 201 pipeline tests, 142 tools tests and 65 validated levels.
Revision 2 corrects the existing export-heading reference so review_pack works.
Historical Android evidence was not repeated in this review; Chris's difficulty
playtest, Galaxy A15 performance and FUN GATE remain open before expansion/release.
Final-head remote CI remains required before merge.
