# T-0281 — P2 completion

Reference: DESIGN.md#level-complete, #flow-level-complete; FR-ECON-05, FR-META-01.
Explicit configure_completion follows certified paid/bonus setup. Boot remains P1.
The existing screen specification supplies the UI-high reference. Device feel and
release SDK/store/privacy reviews remain separate gates.

Actual ordinary or paid final completion receipts supply the earned star and base
coin count-up. Bonus chest presentation remains with T-0280, separate from x2.
Postcard credits read the same committed progress; unavailable art has the existing
translated missing-art caption. No generated content or economy policy changes.
Canonical double unlock/flag/multiplier controls the optional ad-badged button.
Only the existing Monetization rewarded flow invokes bound Economy.grant; its
pending earned write retries without another ad and blocks Continue. Retained
reentry preserves presentation state, completed slots cannot remount certified paid
owners. This uses existing transient rewarded settlement, without a new save format
or a claim that an in-flight ad survives process termination.

Nav's explicit exact-owner continuation opt-in serializes Monetization's legal and
interstitial flow before applying existing postcard/next-level routing. Synchronous
callbacks, async failure retry and stale/duplicate callbacks are covered. Scenes do
not implement consent, ATT or interstitial ordering.

New real-owner integration cases cover ordinary/paid completion, base/chest reward
separation, missing art/progress, x2 success/duplicate/RemoveForcedAds, no-fill and
early close, failed write retry without another ad, unlock/zero reward/multiplier1/
disabled offer, retained reentry/normal count-up cleanup, owner guards, sync/async
Continue, UMP→ATT→SDK initialization, interstitial close, postcard routing, retry,
watchdog and host teardown. Existing tests unchanged.

24 native X11 PNGs show ready and doubled completion in
COMPACT1080x1920/REGULAR1080x2340/TABLET1440x1920 × PL/PSEUDO × default100/HC130.
Actual production controls and services use isolated content/Fake providers and
controlled unlocks. Reduced motion stabilizes captures; normal motion is tested
separately. Assertions verify on-screen number, numeric pills, postcard progress,
credits and both actions, touch minimums, committed balances and base-only doubling.
The compact PSEUDO HC130 images were inspected. Numeric pills reserve measured font
width for their values; generated themes remain unchanged. No script/render errors;
only the known Mesa VSync warning.

Reproduce with pinned Godot4.7.2 and an available X11 display:

```sh
DISPLAY=:102 /path/to/godot --path game --display-driver x11 \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script ../docs/qa/T-0281/capture.gd
```

Full local check, independent review and all15 CI receipts are recorded in the PR.
