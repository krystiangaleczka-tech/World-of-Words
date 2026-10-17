# T-0279 — contextual Hint offer

References: DESIGN.md#flow-stuck-player and #level-p2-final; FR-HINT-07.
The opted-in paid P2 screen uses actual owner bindings, canonical offer thresholds,
one-shot timers and an injectable monotonic Clock. Ten actual-screen tests cover
idle boundaries, invalid streak resets, ignored releases, LEVEL/BONUS/ALREADY_FOUND,
once-only display, reward/modal and failed-write suppression, completion, locked
Hint, stale configuration, retained reentry and application suspension. No sleeps.

The offer composes the existing HintButton highlighted state (stock maximum three
pulses; reduced motion stays static) with Caption text immediately below the play
area, right aligned beside Hint. A noninteractive Control reserves its wrapped height even while hidden; showing
and dismissing the caption leave wheel geometry unchanged. Input remains active.
The hold uses TOAST_HOLD even in reduced motion. It never opens a Sheet or spends.
A local stuck_offer_shown(trigger) is available for T-0328; no Analytics delivery is
activated here. A new screen/process creates a new visit, with no save-format flag.

## Native evidence

12 actual production-screen PNGs: COMPACT 1080x1920, REGULAR 1080x2340, TABLET
1440x1920 × PL/PSEUDO × default100/HC130. Isolated three-level T-0336 fixture and
explicit Hint unlocks; no shipped content or pricing change. Capture reduced motion
for stable geometry; normal-motion cleanup is separately tested. Compact PSEUDO
HC130 checked visually: wrapped copy remains readable, inside viewport, below the
wheel and the highlighted Hint. Automated checks cover all twelve geometries.

Reproduce with pinned Godot 4.7.2 and an X11 server:

```sh
DISPLAY=:101 /path/to/godot --path game --display-driver x11 \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script ../docs/qa/T-0279/capture.gd
```

Only the known Mesa VSync warning occurred in the successful capture run. An initial
attempt found the prior X server stopped; a fresh dummy Xorg server enabled native
captures. No script/render error is accepted as evidence. Device feel, screen-reader
and release gates remain separate; Boot/Nav P2 activation is unchanged.

Final full-check, independent review and CI receipts are recorded in the PR.
