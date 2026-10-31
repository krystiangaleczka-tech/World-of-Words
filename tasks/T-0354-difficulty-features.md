---
id: T-0354
title: Extract deterministic offline difficulty features
epic: E22
type: contract
area: pipeline.scoring
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0127, T-0238]
touch:
  - pipeline/src/wordgame_pipeline/scoring/__init__.py
  - pipeline/src/wordgame_pipeline/scoring/features.py
  - pipeline/tests/scoring/test_features.py
  - docs/contracts/scoring.md
  - tasks/epics/E22-content.md
  - tasks/T-0354-difficulty-features.md
revision: 1
---

## Goal
Extract ROADMAP T-0298 feature computation as an independent offline contract from
existing P1 levels/evidence. This does not depend on a paid classification run.

## Context
CONTENT.md#curve lists letter count, word count/lengths, frequency, anagrams,
grid topology/intersections. Decision0004 preserves Polish tiles and source forms.
P1 keeps difficulty0.0; T-0296 production classification/private-repo/key/spend and
T-0297 suggestions remain gated. No existing stage handler is activated/changed.

## Current state
Preflight main65eec83: exported levels contain letters, words placements and grid;
LanguageConfig/load_config and tiers.valid_word exist. grid.geometry validates
portrait connected crossword geometry. Annotation exposes nullable exact-form ARF.
No scoring module or production scoring/curve config exists.

## Interface
extract_features(level:Mapping, frequencies:Mapping[str,float|None],
config:LanguageConfig)->dict[str,float]. Frequencies are exact selected-form ARF,
never guessed lemma/bonus/AI evidence. Keys must match selected words exactly.

## Specification
- Validate only required scoring inputs: normalized configured3..8 wheel tiles,
  nonempty unique normalized formable selected words in placement dictionaries
  {w,x,y,dir}; canonical existing geometry and exact declared grid. Additional
  exported fields remain untouched. No claim of tier/bonus/source/slot validation.
- Return fresh finite floats in the closed FEATURE_NAMES order:
  letter_count,distinct_letters,word_count,mean_word_length,max_word_length,
  mean_log_arf,frequency_coverage,anagram_pairs,grid_area,grid_fill,crossings,
  crossing_fraction. Mean log1p(ARF) uses known forms only; if none,0 plus coverage0.
  Coverage known/selected; anagram_pairs unordered selected pairs with same letter
  multiset; occupied cells/area fill; crossings=sum(lengths)-occupied cells and
  crossing_fraction=crossings/occupied cells. Bonus words never affect features.
- Reject missing/extra frequency keys, bool/negative/nonfinite/unrepresentable
  ARF, malformed inputs and grid mismatch with ValueError before returning data.
  Reordering tiles/placements/frequency inputs preserves results. No writes, global
  RNG/clock/network/native morphology, stage/export/validator changes or weights.
- Document feature definitions and bounded wave: T-0355 explicit configured scoring,
  T-0356 duplicate/repetition audit. No production calibration/content approval.

## Tests
Exact small hand-calculated crossing/anagram features; single/repeated-letter
levels; partial/all-missing frequency vs real zero; ordering/nonmutation/freshness;
invalid tiles/formability/placements/grid/frequency; all65 current shipped levels
read-only with unknown frequencies, finite results. Full check/review/exact-head CI.

## Rollback
Squash revert removes unused offline module; no shipped or persisted changes.


## Merged-task status reconciliation (2026-10-30)

Implementation was merged on main in [PR #237](https://github.com/krystiangaleczka-tech/World-of-Words/pull/237) with 16/16 exact-head CI success. Planner metadata corrected from stale `review` to `done`; executable code and released content were not changed.
