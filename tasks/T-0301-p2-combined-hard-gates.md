---
id: T-0301
title: Combine real P2 campaign hard gates without activating publication
epic: E22
type: contract
area: pipeline.validate
risk: high
executor: sol
think: xhigh
ui: none
status: blocked
depends_on: [T-0300, T-0206]
touch:
  - pipeline/src/wordgame_pipeline/validate/p2_campaign.py
  - pipeline/tests/validate/test_p2_campaign.py
  - tasks/T-0301-p2-combined-hard-gates.md
revision: 1
---

## Goal

Run the existing authoritative `validate_level`, canonical Godot COMPACT token
geometry, T-0299 crossword/seed duplicate policy, T-0368 difficulty-window
gate, and T-0361 released-slot geometry lock on every planned level.

## Specification

- Reject wrong order, missing/duplicate levels, source-tier, schema or
  geometry violations; ensure selected words and bonus evidence are canonical.
- Import CELL_MIN, gap and GRID_MIN_RATIO from canonical `game/ui/tokens.gd`
  at validation time; supply measured COMPACT body/area sizes explicitly.
- For publication, require an explicit existing release lock. Never synthesize
  human approval or a new baseline.
- Preserve existing P1 released geometry and allow only independently
  semantically validated bonus corrections. Do not modify `game/content/`
  or schema files.
- Tests replay the unchanged 65-slot shipped fixture against all gates,
  reject changed release geometry, incorrect COMPACT measurements, and
  duplicate/missing campaign levels.

## Blockers

This pure gate is necessary, not sufficient: production tuning, actual 200
approved levels, full regions/location manifest v1.1 in T-0302, human QA
T-0304/T-0305/T-0307 and device measurements remain outstanding.
Task dependencies not merged; draft until CI and independent review.
