---
id: T-0125
title: Harden deterministic portrait crossword grid construction
epic: E08
type: feat
area: pipeline.grid
risk: high
executor: sol
think: med
ui: none
status: ready
depends_on: [T-0124, T-0032]
touch:
  - pipeline/src/wordgame_pipeline/grid/**
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/tests/grid/**
  - pipeline/tests/test_pipeline_contract.py
  - pipeline/tests/ingest/test_ingest.py
  - pipeline/tests/tiers/test_tiers.py
  - pipeline/tests/candidates/test_candidates.py
  - docs/CONTENT.md
  - tasks/T-0125-pl-grid.md
  - tasks/T-0124-pl-candidates.md
revision: 1
---

## Goal
Build deterministic connected portrait grids from candidate word pools, hardening the S4 prototype against accidental adjacency and invalid overlaps. Preserve complete bonuses and handmade intent for subsequent validation/export.

## Context
- ROADMAP T-0125; FR-CONT-06; CONTENT.md#hard-validation.
- S4 in pipeline/spikes/s4/generator.py supplies bounded greedy/backtracking placement ideas; do not modify spike code or its tests.
- CONTENT requires connected grids, each selected word once, at most 10x10 and no accidental strings. Portrait aspect here means height >= width; P2 pixel geometry is outside this task.

## Current state
- T-0032 done; prototype Pool/Placement/Level, _can_place/_candidates/_layout and seeded generate_levels exist.
- T-0124 candidates artifact contains pinned provenance and rules/override/handmade hashes, automatic wheels (id, letters, seeds, level_ok/bonus_ok pools) and handmade entries (slot, letters, words, bonus, expect_bonus, optional grid placement list).
- Existing level schema placement has w/x/y/dir, dir h/v, coordinates 0..9; grid dimensions use w/h.
- CLI stops at grid; four scoped test files assert that boundary. grid package does not exist.
- T-0124 is merged; mark status done as bookkeeping.

## Specification
1. Pure builder accepts a unique nonempty normalized word pool, required seed word, injected integer seed and explicit bounded search options. Harden S4: crossing letters must match, same-direction overlap is forbidden, words cannot touch at their ends or alongside newly occupied cells, and every added word crosses the existing connected grid. Bounding box <=10x10.
2. Start with a greedy layout, then bounded backtracking across multiple deterministic restarts. Select best by selected word count, then crossing count, then smaller bounding area, then canonical placement ordering. Return a valid partial subset when all pool words cannot fit; required seed must remain. No unseeded randomness, time-based limits or Python randomized hash identities. Default search limits: 4 restarts, 128 search nodes per restart, 3 placement branches, 16 considered pool words and 6 selected words maximum. These are offline search budgets, not final slot balance. Expose options for tests/callers and carry them in stage metadata.
3. Normalize coordinates to zero origin, transpose when width > height, and canonicalize placements by word. Standalone geometry validation checks shapes, exactly one placement per expected word, matching letters, no same-axis overlap, connected occupied cells, <=10x10, portrait and every maximal horizontal/vertical run of length >=2 corresponding exactly to an intended placement. Invalid explicit layouts fail clearly. Do not add or alter pipeline.validate; geometry checks belong to this grid task.
4. For each automatic wheel use its first sorted seed as the required seed and derive a stable integer search seed from SHA256 of candidate ID. Select only level_ok words. Output selected words/placements, grid w/h, letters, original candidate ID and search seed; complete bonus is the union of both eligible pools minus selected words. Keep candidate order stable and upstream provenance/hashes. Single-word wheels remain valid portrait candidates; final sequencing/balance chooses slots later.
5. Handmade entries must place all specified words: use explicit placements if provided or search with all words required (never silently drop a handmade word). Normalize/transpose explicit grids and enforce geometry; preserve slot, letters, expected bonus and full computed bonus. Unplaceable or invalid handmade content fails without replacing previous artifact. Automatic discovery and handmade entries remain separate collections; no exported IDs/packs or repetition sequencing here.
6. Register grid using the existing atomic runner and verify pinned SJP/annotation metadata. Unchanged repeated builds byte-identical. CLI next unavailable stage is validate (scoring is P2), update only the four existing boundary assertions and corresponding requests. Document output, limits and unplaceable behavior.

## Tests
pipeline/tests/grid/test_grid.py:
- test_geometry_rejects_conflicts_and_accidental_runs: mismatched crossings, collinear overlaps, touching/end adjacency, disconnected words, duplicate placements, dimensions and malformed shapes.
- test_builder_backtracking_and_best_layout: deterministic repeat, multiple restart score >= first greedy/restart, required seed, unplaceable subset, complete handmade failure, no input mutation.
- test_grid_invariants_property: Hypothesis seeded/generated normalized pools; every returned layout connected, intended maximal runs only, <=10x10, height>=width and deterministic.
- test_stage_atomicity_and_bonus: injected candidates, complete leftover bonus, handmade generated/explicit layout, invalid handmade preserving prior artifact, stale pins, CLI validate boundary, byte-identical repeat.

## Acceptance
Pinned Godot make check, task lint/scope, independent fresh review, all CI checks. Run grid stage on actual pinned full-source candidates and repeat, report counts, sizes and hashes; no synthetic data presented as native evidence. No phone build required (no runtime changes).

## Rollback
Revert task and rebuild ignored artifacts. No shipped content, runtime saves or released slots changed.
