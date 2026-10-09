---
id: T-0124
title: Build deterministic Polish word candidates and import handmade YAML
epic: E08
type: feat
area: pipeline.candidates
risk: medium
executor: sol
think: med
ui: none
status: review
depends_on: [T-0123]
touch:
  - pipeline/src/wordgame_pipeline/candidates/**
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/pyproject.toml
  - uv.lock
  - pipeline/tests/candidates/**
  - pipeline/tests/test_pipeline_contract.py
  - pipeline/tests/ingest/test_ingest.py
  - pipeline/tests/tiers/test_tiers.py
  - docs/CONTENT.md
  - tasks/T-0124-pl-candidates.md
  - tasks/T-0123-pl-tiers.md
revision: 2
---

## Goal
Find every source-valid word formable from a seed letter multiset, retaining tier distinctions, and import handmade levels for the subsequent grid stage.

## Context
- ROADMAP T-0124; CONTENT.md#stages-and-artifacts and #hand-made-levels.
- CONTENT.md#word-tiers: level_ok may be grid or bonus; bonus_ok may only be bonus; banned is never accepted.
- FR-CONT-02 and FR-CONT-06: complete bonus evidence and deterministic output.
- Handmade levels bypass automatic seed discovery; importing them alongside automatic candidates does not generate their grid.

## Current state
- T-0123 merged as PR 68; mark its status done as bookkeeping.
- tiers.handlers_for(root) emits pinned source/annotation metadata, tier rules and override hashes, sorted records with word/tier and audit metadata.
- CLI registers ingest/normalize/annotate/tiers and stops at candidates; three scoped assertions name that boundary.
- LanguageConfig has alphabet/min_length/max_length and optional TierRules.
- candidates and handmade directories do not exist. PyYAML 6.0.3 is already locked transitively through gdtoolkit, but is not a declared pipeline runtime dependency.

## Specification
1. Declare PyYAML==6.0.3 as a direct pipeline dependency after Chris approves S7. Use safe loading with explicit rejection of duplicate mapping keys; reject YAML aliases, custom tags and multiple documents. No source downloading or native analyzer calls in this stage.
2. Build an anagram index from validated sorted unique tier records. Signature is a sorted multiset of exact Polish characters. For a wheel, enumerate submultisets and retrieve every formable non-banned word; repeated letters and diacritics retain exact multiplicity. Return sorted level_ok and bonus_ok pools separately. All level_ok words remain possible bonus words if not selected by grid.
3. Every level_ok word is an automatic seed. Deduplicate identical wheel signatures; retain sorted seed words, canonical sorted letters and the complete pools. Require at least one level_ok word; do not impose a new balance threshold or select crossword subsets in this stage. Stable candidate IDs derive from the canonical letter signature. Output sorting is independent of dictionary insertion order.
4. Load optional handmade/<lang>/*.yaml in sorted relative-path order. Accept a top-level list of entries with positive unique slot, letters (3..max_length uppercase alphabet tiles), nonempty unique words, optional unique expect_bonus, and optional grid as placements using the existing level-schema word placement shape. Every listed crossword word must be source level_ok and formable. expect_bonus must be formable and non-banned, and must not be a selected crossword word. Compute the complete bonus list from both eligible tiers minus selected words. Preserve explicit grid placements for the grid stage; reject unknown fields and malformed shapes. No onboarding content authored here.
5. Register candidates via the existing atomic runner. Carry upstream source pins, rules/override hashes and a canonical hash of sorted handmade paths plus exact bytes. Include automatic candidates and handmade entries as separate collections. Verify current pinned source/annotation provenance. Unchanged builds are byte-identical; invalid handmade input leaves prior artifact intact. CLI next unavailable stage becomes grid; update only the three scoped boundary assertions.
6. Document candidate artifact data and safe handmade import. Repetition spacing remains the responsibility of later sequencing/export tasks; candidate pools may overlap.

## Tests
pipeline/tests/candidates/test_candidates.py:
- test_submultisets_and_tiers: anagrams, shorter subsets, repeated letters, diacritics, banned exclusion and sorted complete pools.
- test_seed_signature_deduplication: identical wheels deduplicate with sorted seeds, stable IDs and deterministic input handling.
- test_handmade_validation_and_bonus: documented YAML example, complete bonus, unknown word/tier, malformed letters/slot/grid, duplicate keys/slots, aliases/tags and conflicting expected bonus.
- test_stage_determinism_and_atomicity: injected tier evidence, repeated full-source candidate build, handmade hash changes, stale pins, invalid input preserving old artifact, CLI grid boundary.

## Acceptance
make check, task scope/lint, independent fresh review and all CI checks pass. Attach actual pinned-source candidate counts and repeated artifact hashes if native annotation is available; otherwise escalate the missing real-data execution requirement instead of claiming synthetic evidence as native.

## Escalation
S7: Full YAML import needs a declared runtime parser. Proposed: promote already locked PyYAML 6.0.3 to pipeline/pyproject.toml dependencies, update uv.lock workspace metadata. Chris approved this exact proposal on 2026-10-09. No package version change; implementation may proceed. Alternative: restrict handmade files to JSON-compatible YAML, which would reject the documented flow-style YAML example and therefore requires a contract change.

S2: Preflight found a third boundary assertion in pipeline/tests/tiers/test_tiers.py::test_stage_repeat_override_change_and_failure_atomicity. Once candidates is implemented its final CLI check must request grid and expect "grid is not implemented". This file is outside the frozen touch list; no test was changed. Chris approved this scope addition on 2026-10-09: this file, only that obsolete CLI assertion.

## Rollback
Revert task commits and rebuild ignored derived artifacts; no runtime saves or shipped content changes.
