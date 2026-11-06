---
id: T-0282
title: Tune Level Motion and Ease based on owner device playtests
epic: E20
type: feat
area: ui.tokens
risk: low
executor: cheap
think: med
ui: high
status: blocked
depends_on: [T-0281]
touch:
  - game/ui/tokens.gd
  - game/tests/unit/ui/test_v1_tokens.gd
  - docs/design/tokens.css
  - docs/qa/T-0282-device-game-feel.md
  - tasks/T-0282-device-game-feel-tuning.md
revision: 1
---

## Goal
Tune existing Motion/Ease values, not animation structure, from Chris's hands-on low-end Android and iPhone review of the completed P2 Level.

## Context
DESIGN.md#level-motion, #reduced-motion-mapping, #rules-quote-these-into-ui-tasks; NFR-01; ROADMAP.md T-0282. Existing UI must remain token driven and accessible.

## Current state
T-0281 is `review` on main; required T-0227 haptics and T-0228 audio task files are not yet materialized on main. No owner game-feel feedback with measured device/build and exact token deltas exists. Do not guess new motion values or redesign Level.

## Specification
1. After owner checks T-0281, T-0227 and T-0228, record real builds and qualitative rubric on at least low-end Android and iPhone: initial swipe, backtrack, valid/bonus/invalid feedback, cell flight, hint, level complete, rewarded, reduced motion, audio/haptic synchronization.
2. Record before/after `Motion.*` milliseconds and `Ease.*` settings with a short motivation for each; **change only existing token values** in `game/ui/tokens.gd`. Do not alter structure, UI layout, economy, config or provider logic.
3. Respect `Motion.CELEBRATE` cap, minimal input lock duration, and accessible reduced-motion mapping. Preserve the CSS mirror and tests when token values change.
4. Chris repeats same device/play scenarios and approves or records corrective feedback. Revisit no more than two failed rounds before escalation.
5. R-UI-1 reuse existing components; R-UI-3 no hardcoded view motion; R-UI-4 no copy changes; R-UI-5 do not edit generated theme. Capture screenshot/clip references as specified in DESIGN.md#pr-screenshot-rules when UI behavior changes.

## Tests
`docs/qa/T-0282-device-game-feel.md`: device/build/duration/gesture matrix, before/after token values, reduction mode, audio/haptic observations and owner acceptance. Token unit tests and full `make check` after a measured edit.

## Acceptance
Blocked until certified devices, haptics/audio and T-0281 are available. Done only after a **real** two-platform approved tuning round; no fabricated feedback or arbitrary default tweaks.

## Planning dependency gate
Add T-0227 and T-0228 to `depends_on` only when their task files exist and are `done`.
