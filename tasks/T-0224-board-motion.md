---
id: T-0224
title: Add letter flights landing flash and bounded completion wave
epic: E14
type: feat
area: level.board
risk: high
executor: sol
think: high
ui: low
status: review
depends_on: [T-0223]
touch:
  - game/ui/components/BoardView.gd
  - game/ui/components/GridCell.gd
  - game/features/level/level.gd
  - game/ui/tokens.gd
  - game/ui/theme/generate_theme.gd
  - game/tests/unit/ui/test_v1_tokens.gd
  - docs/design/tokens.css
  - game/tests/integration/test_board_motion_final.gd*
  - game/tests/integration/test_level_completion.gd
  - game/tests/integration/test_debug_level_playtest.gd
  - game/tests/integration/test_debug_level_tools.gd
  - docs/qa/T-0224-board-motion.md
  - tasks/T-0224-board-motion.md
revision: 2
---

## Goal
Finish presentation motion A without delaying persistence or changing game rules.

## Context
Roadmap T-0224; docs/DESIGN.md#level-motion/#reduced-motion-mapping; FR-BOARD-03.
Ghosts preview→cell BASE/IN_OUT/STAGGER; landing1→1.1→1 FAST/SPRING; word brightness1→1.25→1
BASE/OUT; wave1→1.12→1 FAST, diagonalSTAGGER then layer alpha/slide48 SLOW, wave+layer≤CELEBRATE.

## Current state
Fresh main b3561e9d contains technically merged T-0223. BoardView reveal_word/reveal_cell/highlight/
play_wave, GridCell reveal/highlight and LevelScreen result/completion wiring exist. BoardState
commits before result signal. Audio registry has no letter_land cue; existing controller side effects
stay unchanged. No ghosts, landing/flash APIs or wave completion signal exist.

## Specification
1. BoardView adds fly_word(cells:Array[Vector2i],origin:Vector2,whole_word:Array[Vector2i]=[])->Error,
   flight_state()->StringName, wave_duration()->float, signal wave_finished. Validate all coordinates,
   finite canvas-global origin and mounted state atomically. Empty cells may flash whole_word.
   Preallocate MAX_TILES passive ghost Labels on enter, attach only during flight, free on exit;
   no new Nodes while tracking swipe. Result presentation owns tweens. Source letter positions span
   preview; targets use existing cell geometry, scale to cell glyph ratio. Logical cells filled
   immediately; letters land in reading order. Replacing/resize/refresh/exit kills old effects,
   removes ghosts, settles logical visuals. Re-entry recreates pool safely. No BoardState mutation.
2. GridCell adds prepare_landing(), land(), flash(), finish_motion(). Landing FAST pop1.1 and flash
   BASE brightness1.25 restore exact transforms/colour. Existing reveal/highlight contracts retained
   for motionB task. No stale tween callbacks; live reduction settles every running cell effect.
3. Word flash covers whole found word including intersections/hints. Wave requested during flight
   waits for landing/flash, then diagonal wave; cap last delay and uniformly speed completion presentation when necessary so flight/landing/flash/wave+SLOW layer≤CELEBRATE. Add GridCell.set_motion_speed(speed:float)->Error for finite positive presentation-only scaling.
   wave_finished emits once on completed wave; replacing cancels silently, resize may settle/finish
   a waiting completion so it cannot deadlock. Refresh cancels all board work.
4. Initially reduced: no ghosts/pop/wave; cells FAST crossfade in place, final state available
   immediately. Live reduction: settle in place, no movement or new work in _process.
5. LevelScreen uses fly_word for newly revealed cells and entire matching word for flash. Completed
   layer stays in existing body/persistence flow and appears after wave with normal alpha+slide; resume/reduction
   shows directly. Resize/exit settle layer; controls/persistence/controller/event contracts unchanged.
6. Add LANDING_SCALE/WORD_FLASH_SCALE layout tokens with generated CSS/unitless mirror; no hand-edit
   generated themes. No audio/event registry inventions for unavailable per-letter cue.

## UX rules
R-UI-1: "A screen task may not create a component."
R-UI-3: "Use Tokens.*, theme type variations or theme constants."
R-UI-4: "Strings shown to players use translation keys."
R-UI-5: "Never edit game/ui/theme/generated/."
R-UI-6: screenshots per DESIGN.md#pr-screenshot-rules; device/taste gates stay open.

## Tests
New integration: atomic config, actual ghost positions/stagger/landing/flash/restoration, no gameplay
mutation; replacement/refresh/resize/exit/re-entry; wave waits/budget/exactly-once; reduction before/
during, native passivity; LevelScreen completion motion/persistence remains covered by existing suite.
Existing completion assertions retained, with deterministic tween settling before checking the
new delayed layer presentation. Full make check, native normal/reduced snapshots, independent final-head review,13CI before merge.

## Out of scope
MotionB, audio assets/registry, economy/save/controller changes, final HUD composition/device gates.

## Rollback
Squash revert affects presentation and visual tokens only; no migration or saved state changes.

## Revision2
DESIGN Motion.CELEBRATE bounds the full last-word→layer sequence, not just wave+layer.
Nominal token structure is preserved; completion compresses the pre-layer stages uniformly
when necessary. Existing debug/completion assertions now settle cosmetic tweens before checking
final layer visibility/geometry; persistence assertions remain immediate and unchanged.

## Validation
412GUT (8new),311pipeline,451tools,14outputs; full make check green. P1 HUD remains
provisional; native captures assess scoped motion only. Existing debug/completion checks keep
all persistence/visibility assertions, with deterministic cosmetic settling for delayed layer.
