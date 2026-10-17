# Feature coaches — T-0292

## Reproduce

Run from the repository root with pinned Godot 4.7.2 and a native X11 display:

```sh
DISPLAY=:105 /tmp/wow-godot/Godot_v4.7.2-stable_linux.x86_64 \
  --path game --display-driver x11 --rendering-method gl_compatibility \
  --audio-driver Dummy --script ../docs/qa/T-0292/capture.gd
```

65 native PNGs: five coaches × COMPACT 1080×1920 / REGULAR 1080×2340 /
TABLET 1440×1920 × PL/PSEUDO (+35%) × default100/HC130, plus five dismissed
COMPACT PSEUDO HC130 states. The capture loads the actual LevelScreen/Home scenes,
shipped PL content and real Save/Config/Economy/Progress/Events owners, with isolated
in-memory storage. Slot and other seen flags are explicit fixture setup through
Save commands, not evidence of earning progression. Bonus eligibility is produced
by an actual persisted controller submission. Default boot/Nav activation is unchanged.

Reference: DESIGN.md feature-unlock gating and docs/design/T-0205 coach mockups.
Inline captions remain outside the wheel rectangle (and thus tile hit circles).
Opted-in Level screens reserve the existing WHEEL_MIN floor so dismissing a coach
cannot move the wheel during a swipe. Journey uses a stable inline bottom row,
font-measured width and measured catalog minimum height, retaining room for its NEW
state after dismissal. Caption and target bounds are asserted in the native script.
Representative compact PSEUDO HC130 hint/Journey images are inspected manually.

## Behavioral evidence

21 new integration tests cover persist-before-paint, independent once flags,
failed-write/named-action retry, foreign pending actions, unrelated flushes,
callback reentry, blocked FIFO queues, navigation settlement without painting,
tutorial prerequisite, missing-language/off-campaign guards, real Save restart, target removal and caption/highlight
ownership. Native touch continues through the dismissed coach to submit the real
wheel's word; native mouse still activates shuffle. Reduced motion retains the full
3.2-second token-derived hold and uses the catalog static highlight.

The actual atomic P2 fixture completes campaign slots 1–11 with the real Progress
owner, verifies Hint/StuckOffer ownership, and opens/closes the real paid ShopSheet
before permitting Reveal coaching. A failed Progress bonus is never eligible even
if an explicit refresh sees its dirty live board. A committed restored bonus is.
Home and Level layout matrices assert bounds and stable target geometry on dismissal.

The external composition owner must explicitly opt in, supply its actual
consent/foreign-modal guard and call refresh_coaches when that guard changes. No
SDK status, consent completion, or prompt-budget claim is guessed here. Physical
device feel/performance and human onboarding playtests retain their existing gates.
