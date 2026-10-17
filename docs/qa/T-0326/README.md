# T-0326 — passive TutorialHand catalog component

Reference: DESIGN.md#tutorialhand-addition and accepted T-0205 Level1 mockup.
Actual pinned Lucide hand.svg, TEXT alpha0.85, MID shadow, SLOW segment duration,
BASE end pause, FAST touch fade and IN_OUT easing. Caption belongs to the caller.
The caller mounts this passive Control above its wheel and below Toasts.

configure copies/validates finite caller-local points; invalid paths preserve the
current presentation. First mounting plays, hidden reconfiguration stays hidden,
and explicit play starts a new demonstration. Exit cancels owned motion; retained
entry cannot resurrect a dismissed hand. Reduced motion draws the full static path
and arrowhead with no hand movement or idle processing. A live reduction cancels
motion. No gameplay, Save, first-word claim or boot activation is performed here.
T-0291 owns the real first-word and durable state integration.

The Gallery Tutorial page composes an actual seeded three-letter wheel, the hand,
an external translated Caption and replay/hide buttons. The Gallery reduced-motion
control selects the arrow. A real native touch/drag/release passes through the hand
and submits all three wheel indices; the same first touch hides the hand. It does
not mark input handled. No gesture or first-word result is fabricated by the component.

Eleven public-behavior integration tests cover invalid/copy behavior, controlled engine
Tween stepping through segment/end/pause/loop, replacement cancellation, touch fade,
hidden relayout, pre/live reduced motion and no idle processing, exit/reentry,
late deferred replay dismissal, real swipe forwarding and twelve-case geometry.
Existing tests unchanged. No sleeps or wall-clock endpoint assertions.

36 native X11 PNGs: playing, hidden, static × COMPACT1080x1920 /
REGULAR1080x2340 / TABLET1440x1920 × PL/PSEUDO × default100/HC130.
Actual production Gallery/controls. Playing is frozen by stepping the engine Tween,
hiding settles through the real FAST fade, and static uses Tokens.reduced_motion.
Assertions verify wheel/caption/path fit and ignored mouse input. Compact PSEUDO
HC130 playing/static images inspected against the accepted mockup: visible licensed
hand, static directional path, external caption, reachable controls and legible tiles.
No script/render errors, only known Mesa VSync warning. Native desktop screenshots
and Fake-era tests do not certify physical-device feel (T-0282).

Reproduce with Godot4.7.2 and an available X11 display:

```sh
DISPLAY=:103 /path/to/godot --path game --display-driver x11 \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script ../docs/qa/T-0326/capture.gd
```

Full check, fresh independent review and all15 CI evidence are recorded in the PR.
