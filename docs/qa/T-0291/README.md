# First-level tutorial — T-0291

The capture loads the actual opt-in P2 LevelScreen with real Save, Progress,
Content, Economy, Config and Events owners. Storage is isolated in memory;
campaign content is the shipped hand-made slot 1 (KOT, bonuses KTO/TOK).
No production boot configuration is changed.

## Reproduce

From the repository root, with the pinned Godot 4.7.2 binary and a native X11 display:

```sh
DISPLAY=:104 /tmp/wow-godot/Godot_v4.7.2-stable_linux.x86_64 \
  --path game --display-driver x11 --rendering-method gl_compatibility \
  --audio-driver Dummy --script ../docs/qa/T-0291/capture.gd
```

48 PNGs: COMPACT 1080×1920, REGULAR 1080×2340, TABLET 1440×1920 ×
PL/PSEUDO (+35%) × default100/HC130 × playing/touched/reduced/completed.
Playing advances the engine Tween by half a SLOW segment. Touched uses a native
wheel press and cancellation; hand disappears, caption remains. Reduced uses
the catalog static arrow without processing. Completed submits a genuine KTO
bonus and asserts committed onboarding step 1 with both lesson visuals hidden.
The wheel remains available after that bonus; normal board-word completion is
covered by the native swipe integration test.

Geometry assertions cover wheel, board, preview and caption bounds. Manual image
inspection includes COMPACT PSEUDO HC130 reduced and playing. Path is K→O→T using
actual shuffled tile centres; caption remains readable without covering controls.
The accepted onboarding mockup and DESIGN.md first-launch/level-P2 specs are the
reference; the existing P2 number-only HUD remains in use.

## Behavioral evidence

13 integration tests exercise real Progress durability, native press/drag/release,
invalid/short/repeated attempts, hints, diagnostic non-persisting sessions,
metadata retry without replay or committing a foreign coach, real atomic P2 checkpoint/completion, navigation failure, retained reentry, resize,
reduced motion and the full layout matrix. Restored board words can be generated
by hints, so they never prove a player solve. Eligible restored bonus words do;
committed teaching metadata always suppresses the lesson.

Physical-device gesture feel, performance, and human onboarding playtests remain
open under their existing tasks. Desktop captures do not certify those gates.
