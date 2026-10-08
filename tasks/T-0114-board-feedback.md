---
id: T-0114
title: Board feedback
epic: E07
type: feat
area: level.board
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0113, T-0101]
touch:
  - game/ui/components/BoardView.gd
  - game/ui/components/GridCell.gd
  - game/ui/gallery/board.gd
  - game/tests/integration/test_board_feedback.gd*
  - tasks/T-0114-board-feedback.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0114 prototype slice, with deterministic tests and explicit service boundaries.

## Context
- docs/GAME_DESIGN.md#word-classes and #hints: ignored short attempts; identity is tile index.
- docs/ARCHITECTURE.md#level-flow and #save: gameplay calls services directly; Events carry effects only.
- docs/DESIGN.md#level-p1-provisional and #tokens: P1 uses provisional token-driven visuals.
- docs/qa/P1-authorized-wave.md records Chris's explicit instruction to execute T-0100–T-0117 now.

## Current state
Read the corresponding dependency commits before execution. LevelData, Save v1, Nav debug routing,
ScreenScaffold/TextButton and the diagnostic token subset already exist. Other listed APIs are created
by this wave in dependency order. Verify actual signatures before editing.

## Specification
Add token-driven reveal letter fade/pop, already-found highlight via highlight_word(cells), hinted distinctmarker andcompletedwordclearinghint state. MotionFAST/BASE, cancel prior tween percell andresetbase style oninterruption; reducedmotion immediate settle. No inputblocking boardeffects. Test transitions through publicstate and finish_frame usingtweenstep whereavailable, no sleeps. Gallery demonstrable feedback methods.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_hint_then_word_fill_clears_marker.
- test_repeated_highlight_and_reduced_motion.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
