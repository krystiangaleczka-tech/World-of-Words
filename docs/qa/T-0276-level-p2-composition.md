# T-0276 opt-in P2 Level composition

Actual native Godot 4.7.2 GLES3/llvmpipe screenshots are in `T-0276/`.
`capture.gd` uses real Content/Save/Economy/Config owners and a seeded wheel.
Run from the repository with a native dummy X server:

```sh
DISPLAY=:100 /tmp/wow-godot/Godot_v4.7.2-stable_linux.x86_64 --path game --audio-driver Dummy --script ../docs/qa/T-0276/capture.gd
```

Twelve screenshots cover COMPACT/REGULAR/TABLET x PL/PSEUDO x default100/HC130.
An additional COMPACT slot-1 shot proves the first-level reduction even with an
already-unlocked campaign fixture. All displayed balances are explicit fixtures.
Native device/taste/FUN certification, TutorialHand, paid mutation, BonusMeter
settlement and the final completion layer remain their later tasks/release gates.
No boot/Nav registration, consent, ad or store operation is activated here.

Compared with `docs/design/T-0205/evidence/shuffle_REGULAR_PL_default.png`:
existing catalog chrome, wheel and corner controls retain their standard tokens.
The number is a leading Label in TopBar; its empty central title is unused. Actual
leading/trailing rectangles are checked rather than the central title's `fits`
flag. Currency width and the BonusMeter count use catalog font metrics plus token
padding, including HC130. BonusMeter follows BoardView and precedes preview; the
whole meter's minimum height is reserved before fitting the grid and wheel.

Seven integration tests cover: explicit opt-in/default P1 free hint; malformed
Config and changed owner binding; first-level hiding; every configured unlock
boundary based on committed campaign progress; pure navigation/shop/powerup
intents with unchanged Save; live wallet changes; native keyboard activation after
exit/reentry; and the 12-case layout matrix (header rectangles, meter ordering,
touch targets, all corners vs every tile hit circle). Existing P1 tests are intact.

Lifecycle review found that LevelScreen skipped ScreenScaffold's exit cleanup,
which could resurrect TopBar during destruction. It now calls the base cleanup;
P2 reentry restores all runtime/button connections idempotently. Early focused
runs exposed and corrected this implementation issue; it was not an engine import
crash. Missing Config keys fail configuration; a changed Save/Economy relationship
hides the HUD and rejects powerup actions without reading a foreign wallet.
