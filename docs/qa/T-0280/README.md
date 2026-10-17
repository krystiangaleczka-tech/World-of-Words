# T-0280 — persistent bonus meter and completion chest

References: DESIGN.md#level-p2-final, #level-complete, #feedback-matrix and
#bonusmeter; FR-BONUS-02/03, GAME_DESIGN.md#bonus-chest.

Explicit configure_bonus_meter after certified paid P2 enables T-0338's same
Progress owner's atomic checkpoints. Actual BonusMeter reads persisted Economy
counts; changed counts animate while unchanged refreshes preserve the fill. BONUS
flies to that meter and an already-found bonus uses its catalog pulse. Before the
unlock, ordinary feedback remains available without bonus credit.

The meter is disabled/noninteractive mid-level, including full state; translated
Caption above the play area explains the completion boundary. Full-state caption
widths use active theme fonts and existing catalog keys/glyph spacing to avoid
narrow wrapped columns in PSEUDO/HC130. It never grants or opens a chest on a tap.

The actual Economy live-settlement signal is accepted only under the Save receipt
publication barrier for the screen's durable current-slot completion. UI stores
presentation metadata, never a reward command. Once the completion layer appears,
it displays catalog RewardBurst(chest, count) and a translated chest/coin summary;
the existing HUD CurrencyPill already counts up the committed balance. Zero reward
still shows opened chests. Retained reentry cancels and does not replay the burst.

On this explicit bonus composition, the completed play area hides and the existing
completion column centers, including when no chest opens. This avoids compressing
disabled wheel-corner actions as reward content occupies height. Default P1/P2 is
unchanged. Full P2 stars, postcard, x2 and Continue/provider ordering remain T-0281.

## Evidence

Ten integration tests use the real screen/controller, actual services and file
storage, isolated valid three-level content and controlled unlock/bonus config.
They cover persistence/recreation/restart, repeated words and disabled full intent,
multiple/zero payouts, ordinary/paid final completion, failed checkpoint/completion
retry, fake non-publication signal rejection, stock normal-motion fill preservation,
exit/reentry cleanup, opt-in guards and twelve-case caption geometry.
T-0338 separately tests all five disk interruption points and fresh process owners.
No physical power-loss claim and no existing test modifications.

24 native X11 PNGs: full meter during gameplay and completed chest in
COMPACT1080x1920/REGULAR1080x2340/TABLET1440x1920 × PL/PSEUDO × default100/HC130.
Reduced motion gives stable captures; normal motion is checked separately. Real
production controls/owners with the isolated test fixture, not shipped balance or
content changes. Native capture assertions verify touch minimums, corner/tile-hit
clearance, completion visibility and reachable summary/Continue controls.

Reproduce with pinned Godot4.7.2 and X11:

```sh
DISPLAY=:101 /path/to/godot --path game --display-driver x11 \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script ../docs/qa/T-0280/capture.gd
```

Compact PSEUDO HC130 full and completion images inspected: full captions no longer
wrap into a narrow column, reward and Continue fit, wheel actions have no overlap.
Only the known native Mesa VSync warning occurred; script/render errors are rejected.
Boot activation, device feel, real SDK/store, screen-reader and release gates remain
separate. Final full-check, independent review and CI receipts are recorded in PR.
