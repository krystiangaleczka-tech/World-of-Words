---
id: T-0168
title: Export debug performance windows
epic: E08
type: feat
area: features.debug
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0167]
touch:
  - game/features/debug/performance_overlay.gd
  - game/tests/integration/test_performance_windows.gd
  - game/tests/integration/test_performance_windows.gd.uid
  - tasks/T-0168-performance-log-windows.md
revision: 1
---

## Goal
Export debug performance windows. Owner requested five more technical tasks before pending P2 human gates.

## Context
Astra Q3 in docs/qa/T-0142-architecture-preflight.md accepts the P1 allocation exception and requires actual device observations; no speculative wheel rewrite.

## Current state
T-0167 snapshot fields exist; overlay configure, set_foreground, snapshot and existing navigation/clock wiring exist; no window_closed signal or window tests exist.

## Specification
Implement T-0165 Debug log windows section, signal window_closed(record: Dictionary). Keep existing readout/locale/release exclusion. Close before reset/detach, avoid empty/duplicate transitions, exclude background. No wheel/gameplay or render/input path allocations added.

## Tests
Real injected-clock Nav/Save/Content + wheel forced draw: emitted navigation snapshot and reset, background snapshot and ignored background, repeated same foreground does not reset/drop history, exit only once, empty windows suppressed, captured dict stable after reset and callbacks cleaned up. Assert record schema/reason/new fields and printed marker through runtime output.

## Acceptance
All behavior and tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/device/FUN GATE approval invented.

## Outcome
Fresh independent review approved 87e156272907bee31550ee009a9f8fb6445abc3d.
Final full make check:260GUT /13171assertions,311pipeline,142tools,65levels.
Four focused tests/49assertions and nine actual engine JSON lines verified.
Initial new-test foreground assumptions failed; fixed fresh gesture and canvas
processing before forced draw. Interim broad run interrupted before GUT; final
full run passes. Scope four files,count453 vs449. Final-head CI required.
