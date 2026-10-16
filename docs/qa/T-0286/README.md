# T-0286 — committed settings application

Reference: DESIGN.md#settings and #accessibility; T-0284 contract. This wave keeps
explicit composition: no Boot/Nav activation and no fabricated OS observation.

## Native evidence

Pinned Godot 4.7.2, X11/Mesa compatibility renderer, actual Save + SettingsRuntime +
SettingsScreen. `capture.gd` injects real file storage with an explicit write-failure
boundary. Reproduce with `DISPLAY=:100 <pinned Godot> --path game --audio-driver
Dummy --script ../docs/qa/T-0286/capture.gd` under a native X server.

48 PNGs: COMPACT 1080x1920, REGULAR 1080x2340, TABLET 1440x1920;
PL/PSEUDO; default100/HC130; top, bottom, text-size Sheet, failed-write retry.
The display selection is persisted before mounting and Runtime applies the exact
generated resource. Error captures attempt the opposite contrast choice, retain
committed contrast and expose the translated error/retry at the scroll footer.

Comparison with the Settings spec: catalog rows and native controls retain their
order; all footer actions remain reachable. The modal contains exactly 100/115/130
percent TextButtons, fits the compact PSEUDO HC130 viewport and dismisses via the
catalog close/back path. The error state disables competing setting controls until
the explicit retry or an owner flush resolves the candidate. No component/theme
edits. A native driver VSync warning is expected, with no script errors/leaks.

## Owner checks

Actual Save tests cover dirty-vs-committed failure, exact retry, another flush,
external winner including detached reentry, atomic lease, invalid values and
reentrant rejection. Six resources and reduced motion apply from committed values.
Actual Audio caches committed SFX/music volume, binds a caller-owned music player
without starting it and combines ad/background pause. Haptics caches the committed
preference. No save copies occur in the letter-touch side-effect path.

Initial preference injection applies only to a fresh document; loaded, migrated
and backup-recovered settings win. Native keyboard slider release, screen reentry,
text-size selection and twelve-case modal/scroll geometry have integration tests.

## Open release gates

Physical Android/iOS screenshots, screen-reader/OS preference observation, music
track selection, SDK/provider actions and Chris's taste approval remain open.
Desktop native evidence does not certify those gates. System defaults and runtime
composition remain caller-owned and unactivated by existing boot.

Preflight receipts: T-0285 is merged as4efc9ce (#199); the theme foundation
dependency T-0207 is already on main asc876b90 (#132), despite its older review
metadata. All six exact resources exist. No out-of-scope task metadata is edited.
Final game suite:782 tests,27,373 assertions;12 new integration tests.
A detached screen reconciles a successful owner flush or external winning value
on remount, clears its stale retry and restores catalog-owned input availability.
