---
id: T-0356
title: Audit candidate duplicates and campaign repetition without reordering
epic: E22
type: contract
area: pipeline.dedupe
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0355]
touch:
  - pipeline/src/wordgame_pipeline/dedupe/**
  - pipeline/tests/dedupe/**
  - docs/contracts/scoring.md
  - tasks/epics/E22-content.md
  - tasks/T-0356-duplicate-audit.md
revision: 1
---

## Goal
Extract the independently testable analysis portion of ROADMAP T-0299. Report all
conflicting pairs without deleting candidates or inventing production thresholds.

## Context
CONTENT.md#hard-validation rejects identical wheel multisets and word sets above
configured Jaccard threshold across campaign/daily pools. CONTENT.md#p1-repetition-
spacing requires every crossword word at campaign slot distance>=100, not only
seed words. Bonus words are excluded. Production sequencing remains separate.

## Current state
Preflight mainc4ff0d0: config.LanguageConfig, tiers.valid_word and deterministic
scoring contracts exist. P1 stage selection leaves dedupe unavailable. No dedupe
module or production threshold config. Existing validators/exports remain owners.

## Interface
Frozen DuplicatePolicy(jaccard_threshold:float,seed_spacing:int),
audit_duplicates(records:list|tuple,policy,config:LanguageConfig)
->tuple[DuplicateConflict,...]. Frozen result fields left_id,right_id,reasons:tuple,
shared_words:tuple,jaccard:float. No CLI/stage integration or content writes.

## Specification
- Policy requires finite non-bool threshold0..1 and integer seed_spacing>=100;
  explicit arguments only. No default production threshold. Fixed crossword
  spacing100 derives from existing CONTENT policy and cannot be lowered.
- Each analysis record exactly {id,pool,slot,letters,words,seed_word}. Unique trimmed
  nonempty control-free ID; pool campaign|daily, positive integer slot; unique
  (pool,slot). Configured normalized wheel list3..8; nonempty unique selected-word
  list, normalized/formable with tile multiplicity. Explicit seed_word must be a
  selected word; never infer it from random numeric seed or word ordering. Caller
  supplies prior tier/grid/source validation and authoritative seed provenance.
- Validate every input before pair analysis. Return all conflicting pairs ordered
  canonically by(pool,slot,id), independent of caller order. No input mutation,
  selection/reordering of actual content, clock/RNG/network or dictionary lookup.
- Reasons in fixed order: letter_multiset (equal sorted tiles, multiplicity and
  Polish diacritics preserved); word_jaccard when intersection/union strictly>
  threshold; word_spacing for any shared selected word at campaign distance<100;
  seed_spacing when equal explicit seed words at campaign distance<seed_spacing.
  Equality at threshold or minimum distance passes that rule. Multiple reasons
  are retained. Bonus data is not an input and cannot affect shared-word checks.
- Multiset/Jaccard comparisons span campaign/daily. Spacing only compares campaign
  records: campaign slots and daily positions have no shared clock; daily pacing
  remains a future policy. Reports contain sorted shared words and exact ratio.
  Invalid policy/record/duplicate ID/position fails ValueError with no partial result.
- Document that production thresholds, candidate filtering, curve/sequence, paid
  classification and publishing remain gated. Existing P1 validation stays intact.

## Tests
Multisets/repeated tiles/Polish distinctions; exact Jaccard boundaries, symmetry,
cross-pool comparison; word gap99/100 and seed gapK-1/K, nonseed recurrence, daily
spacing exclusion; multiple reasons/shared-word order; permutations/nonmutation/
immutable results; malformed policy/record/identity/slot/seed/formability, invalid
later input atomic failure. Full checks/fresh review/all exact-head CI.

## Rollback
Squash revert removes unused analysis only; no generated or persisted changes.


## Merged-task status reconciliation (2026-10-30)

Implementation was merged on main in [PR #239](https://github.com/krystiangaleczka-tech/World-of-Words/pull/239) with 16/16 exact-head CI success. Planner metadata corrected from stale `review` to `done`; executable code and released content were not changed.
