---
id: T-0123
title: Assign deterministic Polish word tiers from evidence and overrides
epic: E08
type: feat
area: pipeline.tiers
risk: high
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0122]
touch:
  - pipeline/src/wordgame_pipeline/tiers/**
  - pipeline/src/wordgame_pipeline/config.py
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/config/pl.yaml
  - pipeline/overrides/pl.csv
  - pipeline/tests/tiers/**
  - pipeline/tests/test_pipeline_contract.py
  - pipeline/tests/ingest/test_ingest.py
  - docs/CONTENT.md
  - tasks/T-0123-pl-tiers.md
  - tasks/T-0134-debug-level-tools.md
revision: 1
---

## Goal
Give every SJP-normalized annotated word exactly one P1 tier and a traceable reason. Overrides retain priority, without introducing source-invalid words or promoting words with no lemma evidence.

## Context
- ROADMAP T-0123; CONTENT.md#word-tiers and #overrides: overrides > rules, newer dated decisions win.
- Decision 0004: base forms plus very frequent inflections; proper nouns/abbreviations/vulgar words excluded.
- Decision 0008: missing frequency does not invalidate words; missing usable lemma means at most bonus_ok.
- Chris requested sequential execution/merge and a minimum distance of 100 levels between word repetitions on 2026-10-09. Record the latter in CONTENT for subsequent sequencing/content tasks; this task does not sequence levels.

## Current state
- LanguageConfig is a frozen dataclass with lang/alphabet/min_length/max_length, to_dict() and strict load_config(root, lang).
- pl.yaml is JSON-compatible YAML with those four fields. Tier settings and overrides/pl.csv do not yet exist.
- CLI registers ingest/normalize/annotate; default execution stops at tiers. Contract and ingest tests assert that first unimplemented stage.
- Annotation produces sorted records with word, analyses (lemma, POS, tag, names, labels, is_inflected, nullable frequency), exact form frequency, coverage, SJP source and annotation_sources.
- StageHandler, run_build and canonical versioned artifacts are implemented; tests can inject annotation handlers without native dependencies.
- T-0122 is done. T-0134 merged; update its status only as bookkeeping.

## Specification
1. Add optional immutable TierRules to LanguageConfig, preserving four-field legacy configs and their to_dict() shape. New config contains finite nonnegative base_min_arf=10 and inflected_min_arf=100, banned_labels=["wulg."], excluded_level_labels=["daw.","przest.","rzad."]. Include settings in the config identity hash. These are provisional candidate-selection defaults; Chris reviews actual words in T-0129 before release.
2. Pure assignment preserves exact input membership/order and annotations. Reject malformed normalized/duplicate input, analyses and frequency. No source download, native dependency or AI call. An ign/no-lemma record is bonus_ok. Any banned label bans the form. An interpretation is ordinary only when it has no proper-name metadata (names empty or only nazwa_pospolita / nazwa pospolita) and POS is not brev. If all known interpretations are proper names/abbreviations, ban the form; a common-word homonym can remain eligible.
3. Ordinary base forms meet base_min_arf using exact form ARF or their own matching lemma/POS ARF. Inflections require exact form ARF >= inflected_min_arf. Excluded-level labels prevent that interpretation from promoting. Otherwise bonus_ok; missing frequency never bans a word. Preserve ambiguity; no lemma frequency substitution for an inflected form.
4. Parse UTF-8 CSV word,tier,reason,date,by strictly. Require normalized alphabetic words, valid tier, nonempty reason/by and ISO date. Sort independently of row order; newest date wins; conflicting same-date decisions fail clearly. Keep unknown-source rows as unmatched audit metadata without adding words. level_ok override still requires usable lemma evidence. Preserve all CSV history; initial file contains header only.
5. Register tiers using existing artifact runner. Verify SJP and annotation pins before consuming payload. Carry source metadata, rules and overrides hashes, tier counts, unmatched overrides and per-record tier/tier_reason/override decision. Repeated unchanged builds are byte-identical; changed overrides change output; invalid input never overwrites prior artifact. CLI now stops preflight at candidates; update the two named legacy assertions only.
6. Record requested P1 repetition policy in CONTENT: any two campaign level occurrences of the same crossword word must have slot distance >=100; there is no required recurrence. Bonus words do not count as crossword occurrences. Enforce in later sequencing/export work, not in tier assignment. No generated game content, validator or released slot changes.

## Tests
pipeline/tests/tiers/test_tiers.py:
- test_base_inflection_nullable_and_ambiguity: threshold boundaries, matching lemma-only base frequency, exact-form-only inflection, no lemma, excluded label, common/proper homonyms.
- test_banned_evidence_and_override_precedence: vulgar/proper/abbrev bans, latest dated override, unknown membership, no-lemma promotion rejected, duplicate/conflicting/malformed rows.
- test_config_and_input_validation: legacy shape, immutable rules, finite/nonnegative thresholds, malformed words/analyses/frequency.
- test_stage_repeat_override_change_and_failure_atomicity: injected annotation, repeat/resume, override hash, stale pins, prior artifact unchanged on malformed CSV, CLI candidates boundary.

## Acceptance
Pinned Godot 4.7.2 make check, task lint/scope, independent fresh review and CI pass. Source/tier preview is synthetic unless native full-source data is available; do not claim actual corpus counts. One branch/PR; no cheap-executor provenance claimed.

## Rollback
Squash revert restores previous config/CLI; derived tier artifacts are ignored and must be rebuilt. No runtime save or shipped content changes.
