# T-0278 — durable paid Hint/Reveal caller

References: DESIGN.md#level-p2-final, #flow-stuck-player, #flow-rewarded, #hintbutton
and #sheet; GAME_DESIGN.md#hints. The executable revision follows the original
blocked preflight, T-0336's joint candidate/proof protocol and T-0337's issued-price
retry fix. Scope does not activate P2 in Boot/Nav or claim open release gates passed.

## Behavior and evidence

Actual LevelScreen/LevelController, certified Progress/AtomicProgressPort/Economy/
Save/Content/Config and real file storage. Paid plans remain detached until a matching
Save receipt. Item-first and canonical coin costs, final completion/rewards, rapid
and synchronous reentry, free-hint bypass, exact failed-write retry, remote price
changes, retained exit/reentry, navigation barriers and ordinary word compatibility
are covered by the new integration suite. Existing tests are unchanged in T-0278.
The prerequisite tests cover all five file interruption points and process restart.

Fake providers exercise actual Monetization and Economy callbacks: reward earned,
early close, no fill, deferred completion, pending write and retry without another
ad. Ads grant configured Hint items; an original Reveal request never auto-consumes
or receives a fabricated Reveal. The existing Shop Sheet switches content in place,
retains its purchase busy barrier and uses actual copied Fake catalog prices.
Native keyboard activation and PL/PSEUDO geometry/touch/copy checks cover 12 cases.

## Native screenshots

Pinned Godot 4.7.2, X11/Mesa compatibility renderer. Reproduce under a native X server:

```sh
DISPLAY=:100 /path/to/pinned-godot --path game --display-driver x11 \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script ../docs/qa/T-0278/capture.gd
```

68 PNGs use the real production controls and owners with the isolated three-level
fixture and explicit test unlocks. This is not shipped content or real store pricing.
COMPACT 1080x1920, REGULAR 1080x2340, TABLET 1440x1920 × PL/PSEUDO × default100/HC130:
write retry, paid Hint, paid Reveal, unavailable-ad options and Shop (60 images).
Eight REGULAR PL examples additionally show ready ad, active ad, reward write retry
and success in both themes. The source script lives outside the shipped game tree.
Only the native driver's known VSync warning is expected; script errors fail evidence.

Inspected compact PSEUDO HC130 offer, retry and Shop; regular busy/reward retry;
tablet paid Reveal. Controls wrap without truncation, disabled ad has a caption,
retry stays reachable, the same Sheet contains Shop content, and success follows
actual durable grant. Catalog Toast plus Hint count pop is used for item reward:
RewardBurst has no Hint-item variant. This is an explicit design refinement, not
an invented chest/coin effect. No custom component or generated theme change.

## Limits and gates

New paid use requires explicit before-mount configuration. The caller must honor
prepare_navigation returning busy; forced destruction of a pending screen while
ignoring that result is unsupported. Retained reentry and process restart are tested
separately. Physical power loss, device feel/screenshots, screen readers, real SDKs,
accounts, stores, monetization activation, FUN and T-0275 analytics remain release
work. The native evidence is not a device/provider certification.

Final full-check, independent review and CI receipts are recorded in the PR.
