---
id: T-0032
title: Prototype the Polish grid generator
epic: E02
type: spike
area: pipeline.grid
risk: medium
executor: cheap
think: high
ui: none
status: review
depends_on: [T-0016]
touch:
  - pipeline/spikes/s4/**
  - pipeline/tests/test_s4_generator.py
  - docs/spikes/S4-generator.md
  - tasks/T-0032-*.md
revision: 1
---

## Goal
Prove that a small deterministic Python grid builder can generate 50 usable Polish word-connect
crossword candidates and leave the code in pipeline/spikes/s4/ as the Phase 1 starting point.

## Context
- docs/design-pass/09-content-pipeline.md section 2: grid construction uses crossword placement,
  eventually with greedy search plus backtracking, multiple seeds and best-layout selection.
- docs/design-pass/11-ryzyka-i-fazy.md section 4: S4 must generate 50 levels from a small PL list,
  render ASCII grids and record a quality assessment.
- tasks/epics/E02-spikes-engine-gate.md D2: unlike other spike code, S4 code stays on main and the
  spike report is docs/spikes/S4-generator.md.
- Roadmap row T-0032.

## Current state
- T-0016 is done and supplies Python 3.11, uv, pytest and ruff.
- pipeline/spikes/s4/ and S4 report do not exist on main.
- The production grid stage is intentionally not implemented yet.

## Specification
### Behavior
1. Keep a small hand-curated PL spike input separate from production dictionary data.
2. Generate exactly 50 deterministic level candidates from a fixed seed.
3. Every selected word must be buildable from the level wheel letters.
4. Place all selected words in one connected crossword using matching-letter crossings.
5. Reject conflicting placements and side-touching parallel words.
6. Render each level as a text grid and report the wheel, selected words and dimensions.
7. Record quantitative results and qualitative limitations in the S4 report.

### Edge cases
| Case | Expected |
|---|---|
| malformed input pool | fail with a clear ValueError |
| word cannot be built from wheel | fail while loading the pool |
| requested count cannot be reached | fail rather than silently emit fewer levels |
| placement search explodes | bounded search returns failure for that candidate set |

## Out of scope
- Licensed dictionary ingest, tiers, scoring, hard validator, dedupe across campaign slots, JSON export.
- Production LevelData schema or game runtime changes.

## Tests
File: pipeline/tests/test_s4_generator.py
- test_s4_generates_50_levels_deterministically: two runs with seed 32032 are byte-identical and each
  contains exactly 50 levels.
- test_s4_levels_are_phone_sized_and_ascii_rendered: all 50 rendered grids are text-only and no
  dimension exceeds 10x10.

## Acceptance
- The two tests above pass and make check stays green.
- docs/spikes/S4-generator.md states whether S4 is feasible and names the Phase 1 hardening work.

## Escalation log
- S1: ROADMAP and E02 define T-0032 but no task file existed on main. Chris explicitly requested
  execution, so this branch records the frozen scope without editing ROADMAP.
- S2 resolved by T-0052: CI run 60 detected the pipeline diff and executed `make pipeline-test`.
  The first real run exposed an over-10x10 layout; the generator now rejects oversized candidates and
  the rerun passed all pipeline tests.
