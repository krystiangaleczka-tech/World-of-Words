# S1 platform SDK spike plan

Research snapshot: **2026-10-03**. Engine under test: **Godot 4.7.2 standard build, typed GDScript**.
T-0027 runs Android first; T-0028 repeats applicable rows on iPhone. T-0026 installs no SDK.

## 1. Plugin survey and S1 choices

| Capability | First choice | Bounded fallback | Main risk / evidence |
|---|---|---|---|
| AdMob + UMP + ATT | Poing Studios Godot AdMob, current stable at execution | `godot-sdk-integrations/godot-admob` v7.x | Poing documents Godot 4.5+, Android+iOS, UMP and IDFA/ATT and was active Sep 2026. Community v7 has equivalent UMP/ATT signals, but open issue #124 reports initialization trouble on Godot 4.7. |
| Play Billing | `godot-sdk-integrations/godot-google-play-billing` | none; escalate | Maintained master documents Godot 4.2+ and Gradle export. Must expose purchase token and correct consume/restore behavior. |
| StoreKit 2 | `godot-sdk-integrations/godot-storekit2` | OpenIAP Godot 2.x | Dedicated plugin says its API is still unstable. OpenIAP supports Godot 4.x/StoreKit 2 but its prebuilt iOS path requires iOS 17+ and has Godot 4.7 GDExtension warning noise. |
| Analytics + crash | `godot-x/firebase` Analytics + Crashlytics | HTTPS analytics; crash provider later | Plugin declares Godot 4.7-stable, Android+iOS, prebuilt AAR/XCFrameworks and privacy-safe defaults. HTTP analytics is valid fallback; raw HTTP is not a native crash/symbolication substitute. |
| Haptics | `toniqat/godot-haptics` | tiny iOS impact bridge | Exposes UIFeedbackGenerator/Android effects and an enabled toggle. A small haptics bridge is allowed by decision 0001. |

Do not use `godot-sdk-integrations/godot-ios-plugins` InAppStore for S1 IAP: its current path is
StoreKit 1, while S1 requires StoreKit 2. The archived `hyochan/godot-iap` repository is historical
only; current development moved to OpenIAP.

Sources checked:
- https://github.com/poingstudios/godot-admob-plugin
- https://poingstudios.github.io/godot-admob-plugin/latest/privacy/user_messaging_tools/get_started/
- https://poingstudios.github.io/godot-admob-plugin/5.0/privacy/user_messaging_tools/idfa_support/
- https://github.com/godot-sdk-integrations/godot-admob
- https://github.com/godot-sdk-integrations/godot-admob/issues/124
- https://github.com/godot-sdk-integrations/godot-google-play-billing
- https://github.com/godot-sdk-integrations/godot-storekit2
- https://www.openiap.dev/docs/setup/godot
- https://github.com/godot-sdk-integrations/godot-ios-plugins/issues/57
- https://github.com/godot-x/firebase
- https://firebase.google.com/codelabs/firebase_mp
- https://posthog.com/docs
- https://github.com/toniqat/godot-haptics

### Provider rules

For ads/IAP, make one documented setup attempt with the first choice; on a plugin-specific failure,
capture the exact error and try only the listed fallback. Do not invent a third ads/IAP candidate
inside T-0027/T-0028. If passing requires writing/substantially rewriting native ads/IAP code, fail S1.

For analytics/crash, try Firebase first because one Godot 4.7-compatible candidate covers P6/P7 and
consent-sensitive startup. If Analytics fails, use plain HTTPS event delivery behind the adapter
(PostHog-style capture or GA4 Measurement Protocol). Sentry is not selected for S1: this survey found
no clearly maintained Godot 4.7 Android+iOS Sentry plugin, and HTTP error posts do not prove native
crash capture/symbolication. Analytics/crash provider failure alone does not fail the engine gate.

## 2. Store/platform constraints to verify

- **Play target:** new apps/updates from 2026-08-31 require Android 16 / API 36+:
  https://support.google.com/googleplay/android-developer/answer/11926878
- **16 KB pages:** Godot supports them out of the box since 4.5, but every native SDK in the AAB still
  needs inspection. Current Play enforcement for updates targeting API 35+ is 2027-02-01:
  https://godotengine.org/releases/4.5/ and
  https://developer.android.com/guide/practices/page-sizes
- **Apple privacy:** embedded third-party SDK manifests/signatures and App Privacy declarations must
  match actual SDK behavior; invalid manifests can reject submission:
  https://developer.apple.com/support/third-party-SDK-requirements/
- **ATT:** tracking/IDFA requires authorization; S1 exercises allow and deny:
  https://developer.apple.com/app-store/user-privacy-and-data-use/

Record each selected plugin's minimum OS. Notable survey floors: Poing AdMob documents iOS 15+;
`godot-x/firebase` declares iOS 13+/Android 24+; current OpenIAP prebuilt iOS requires iOS 17+.
T-0033/Q9 chooses the final supported floor from actual passing integrations.

## 3. Application identifiers

Reserved production identity:
- Android `applicationId`: `com.krystiangaleczka.wordgame`
- iOS bundle ID: `com.krystiangaleczka.wordgame`

S1 throwaway identity:
- Android: `com.krystiangaleczka.wordgame.spike`
- iOS: `com.krystiangaleczka.wordgame.spike`

The `.spike` ID is used for all S1 provider/store resources. Decision:
`docs/decisions/0007-app-identifiers.md`.

## 4. Ordered P1-P11 matrix

Each attempt records plugin tag/commit, native SDK versions, Godot 4.7.2, OS/device, result, evidence
reference and PASS/FAIL.

| ID | Test | Required evidence / pass condition |
|---|---|---|
| P1 | Consent | UMP debug geography where needed; status readable in GDScript; ad SDK initializes only after resolution. iOS: UMP/IDFA explainer then ATT allow and deny on clean installs. |
| P2 | Rewarded | Google test unit: full watch grants exactly once through reward callback; early close grants zero. |
| P3 | Interstitial | Test unit loads/shows/closes and returns to the exact pre-ad game state. |
| P4 | Consumable | Android internal-track purchase → grant → consume with `purchaseToken` visible to GDScript. iOS sandbox purchase → grant → finish with StoreKit 2 `Transaction.id` visible. No double grant. |
| P5 | Non-consumable + restore | Purchase, reinstall, query/restore/current entitlement; entitlement returns on both platforms and is never lost. |
| P6 | Analytics | After permitted collection, one named test event with expected params appears in the provider dashboard. |
| P7 | Crash | Deliberate crash in tagged test build appears in dashboard with app/content version and readable stack. |
| P8 | Haptics | Light/tick feedback is felt when enabled and absent when disabled; iOS uses native impact/selection feedback. |
| P9 | Silent switch | iOS SFX is audible with switch off and silent with switch on. |
| P10 | Store upload | Android AAB accepted on internal track, target API 36 verified and native libs inspected for 16 KB compatibility. iOS archive accepted by App Store Connect and installs from TestFlight. |
| P11 | Stability | 10-minute loop through ads plus purchase/query/restore completes without crash, ANR, hang or lost entitlement. |

Additional evidence:
- min/target Android SDK and min iOS implied by selected plugins;
- iOS privacy manifests for SDKs where required;
- analytics/crash collection state on cold start before consent;
- ATT is retested from a clean install because the system prompt is one-shot.

## 5. Failure classification

**Stop / engine gate failure:** F1 any P1-P5 path lacks an existing maintained plugin and needs a
native ads/IAP plugin written or substantially rewritten; F2 documented ads/IAP setup reproducibly
crashes/hangs/loses a purchase (lost purchase always fails); F3 P10 store rejection for an
engine-level reason export settings cannot fix. F4 remains T-0029: engine-caused perceivable swipe lag.

**Record but do not fail Godot solely for it:** Firebase Analytics failure with working HTTPS fallback;
Crashlytics/provider failure; small iOS haptics bridge; raised minimum OS; plugin-specific bug solved
by the bounded fallback without changing game APIs.

## 6. Execution order

1. Create all test resources against `com.krystiangaleczka.wordgame.spike` only.
2. Pin exact plugin release/commit and native SDK versions before testing.
3. Prove clean export/install, then P1 consent before any ad load.
4. Run P2-P3 ads, then P4-P5 purchases/restore.
5. Run P6-P7 analytics/crash, P8 haptics, and on iOS P9.
6. Run P10 through the real store test path, then P11 stability.
7. Capture exact failure evidence before using a listed fallback; otherwise escalate.
