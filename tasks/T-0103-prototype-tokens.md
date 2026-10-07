---
id: T-0103
title: Prototype tokens
epic: E06
type: contract
area: ui.tokens
risk: high
executor: sol
think: high
ui: low
status: ready
depends_on: [T-0054, T-0055]
touch:
  - game/ui/tokens.gd
  - game/tests/unit/ui/test_p1_tokens.gd*
  - tasks/T-0103-prototype-tokens.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0103 prototype slice, with deterministic tests and explicit service boundaries.

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
Extend existing Tokens without changing diagnostic values. Add DESIGN Palette/Type/Space/Radius/Motion/Ease/Touch/Layout provisional groups and constants required by wheel/board/preview, including ring radius ratio, tile radius ratio, line width and selected scale; geometry ratios are documented additions. static reduced_motion and dur(ms:int)->float: durations greater than FAST become0 when enabled; seconds otherwise. No theme generation/assets yet. Preserve existing TokensType purity tests. All forthcoming UI geometry and visual literals use these constants.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_duration_seconds_and_reduced_motion.
- test_palette_and_geometry_relationships.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.

## Rollback
Revert the isolated squash commit before dependent tasks merge; after dependent integration revert
in reverse order. Save v2 migration is a forward format change: keep v1 backup before any downgrade.
