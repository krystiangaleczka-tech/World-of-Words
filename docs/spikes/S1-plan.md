# S1 platform SDK spike plan

Research snapshot: **2026-10-03**. Engine under test: **Godot 4.7.2 standard build, typed GDScript**.
T-0027 runs Android on the Galaxy A15 first; T-0028 repeats applicable rows on the iPhone 13 Pro Max.
T-0026 installs no SDK.

## 1. Plugin survey and S1 choices

| Capability | First choice | Bounded fallback | Main risk / evidence |
|---|---|---|---|
| AdMob + UMP + ATT | Poing Studios Godot AdMob, current stable at execution | `godot-sdk-integrations/godot-admob` v7.x | Poing documents Godot 4.5+, Android+iOS, UMP and IDFA/ATT and was active 2026-09-30. Community v7 has equivalent UMP/ATT signals, but issue #124 reports Godot 4.7 initialization trouble. |
| Play Billing | `godot-sdk-integrations/godot-google-play-billing` >= 3.3.0 | none; escalate | 3.3.0 uses Play Billing 9.1.0 and exposes `purchase_token`. PBL 7 stopped being accepted for normal new-app/update submissions after 2026-08-31. |
| StoreKit 2 | OpenIAP Godot 2.x | only a future `godot-storekit2` release that exposes `Transaction.id` and defers finish until GDScript explicitly requests it; otherwise escalate | Current OpenIAP exposes explicit finish flow but raises the iOS floor to 17. Current `godot-storekit2` is not eligible as-is: transaction data lacks `Transaction.id` and purchase code finishes natively before the game can durably grant. |
| Analytics | `godot-x/firebase` Analytics | plain HTTPS analytics adapter | Plugin declares Godot 4.7-stable, Android+iOS and privacy-safe consent defaults. HTTP is the provider-independent fallback. |
| Crash reporting | official `getsentry/sentry-godot` 2.x | `godot-x/firebase` Crashlytics | Sentry supports Godot 4.5+, Android+iOS and GDScript script stacks; Crashlytics remains a viable native-crash fallback but must independently prove a readable GDScript trace. |
| Haptics | `toniqat/godot-haptics` | tiny iOS impact bridge | Exposes UIFeedbackGenerator/Android effects and an enabled toggle. A small haptics bridge is allowed by decision 0001. |

Do not use `godot-sdk-integrations/godot-ios-plugins` InAppStore for S1 IAP: its current path is
StoreKit 1. The archived `hyochan/godot-iap` repository is historical; current work moved to OpenIAP.

Sources checked:
- https://github.com/poingstudios/godot-admob-plugin
- https://github.com/godot-sdk-integrations/godot-admob/issues/124
- https://github.com/godot-sdk-integrations/godot-google-play-billing
- https://github.com/godot-sdk-integrations/godot-storekit2
- https://www.openiap.dev/docs/setup/godot
- https://github.com/getsentry/sentry-godot
- https://github.com/godot-x/firebase
- https://firebase.google.com/codelabs/firebase_mp
- https://posthog.com/docs
- https://github.com/toniqat/godot-haptics

### Provider rules

For ads/IAP, make one documented setup attempt with the first choice; on a plugin-specific failure,
capture the exact error and try only the listed fallback. Do not invent a third ads/IAP candidate in
T-0027/T-0028. If passing requires writing/substantially rewriting native ads/IAP code, fail S1.

For StoreKit 2 specifically, the current `godot-storekit2` master is **not** a valid first choice:
its transaction payload does not expose the durable transaction key required by FR-IAP-03, and its
purchase path finishes before GDScript can durably record the grant. It becomes eligible only if an
upstream release fixes both boundaries before T-0028; otherwise OpenIAP is the only S1 attempt.

For crash reporting, compare Sentry and Crashlytics against the same P7 definition. Provider failure
alone does not fail Godot; losing purchases or requiring substantial native ads/IAP work does.

## 2. Store/platform constraints and entry prerequisites

Current upload constraints to verify during P10:
- **Play target:** Android 16 / API 36+ for new apps and updates from 2026-08-31.
- **Play Billing:** PBL 7 deadline was 2026-08-31 (extension to 2026-11-01); use a plugin carrying
  PBL 8+ for S1. Pin the exact billing library version in evidence.
- **16 KB pages:** inspect every native SDK in the AAB; plugin libraries can break alignment even
  though Godot itself supports 16 KB pages.
- **Apple:** since 2026-04-28, App Store Connect uploads require Xcode 26+ and the iOS 26 SDK.
  P10 must prove that Godot 4.7.2 export templates and selected plugins build and upload with that toolchain.
- **Apple privacy:** embedded SDK privacy manifests/signatures and App Privacy declarations must match
  actual behavior.

Sources:
- https://developer.android.com/google/play/billing/deprecation-faq
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.android.com/guide/practices/page-sizes
- https://developer.apple.com/news/upcoming-requirements/
- https://developer.apple.com/support/third-party-SDK-requirements/

Entry checklist before T-0027/T-0028 device work:
- Play Console merchant/payment profile ready; internal-track app, license testers and test products available.
- App Store Connect Paid Applications Agreement active with required banking/tax setup; sandbox testing ready.
- AdMob `.spike` app exists and UMP messages needed for GDPR and iOS IDFA/ATT testing are published.
- Firebase and Sentry test projects/apps are available for the `.spike` identifier.
- Test devices: Galaxy A15 for all Android rows; iPhone 13 Pro Max for all iOS rows; S26 Ultra optional
  for extra haptics/high-refresh observation.

Record each plugin's minimum OS. Notable survey floors: Poing AdMob documents iOS 15+;
`godot-x/firebase` declares iOS 13+/Android 24+; current OpenIAP prebuilt iOS requires iOS 17+.
T-0033/Q9 chooses the final floor from integrations that actually pass.

## 3. Application identifiers

Candidate production identity (pending Chris's explicit acceptance in decision 0007):
- Android `applicationId`: `com.krystiangaleczka.wordgame`
- iOS bundle ID: `com.krystiangaleczka.wordgame`

S1 throwaway identity:
- Android: `com.krystiangaleczka.wordgame.spike`
- iOS: `com.krystiangaleczka.wordgame.spike`

The `.spike` ID is disposable and may be used for S1 resources while the permanent production
namespace remains proposed. It must never be reused as the production store identity.

## 4. Ordered P1-P11 matrix

Each attempt records plugin tag/commit, native SDK versions, Godot 4.7.2, OS/device, result, evidence
reference and PASS/FAIL.

| ID | Test | Required evidence / pass condition |
|---|---|---|
| P1 | Consent | Android/iOS: UMP consent info refreshes and the form appears after slot 1 where required; status is readable in GDScript and ads do not initialize before UMP resolves. iOS: verify the plugin can keep ATT separate: no ATT at slot 1, UMP IDFA explainer + ATT only after slot 6, and no ad request before ATT resolves. If the plugin forces IDFA/ATT into the slot-1 flow, record a PRODUCT decision for Chris rather than an engine failure. Test ATT allow and deny from clean installs. |
| P2 | Rewarded | Google test unit: full watch grants exactly once through reward callback; early close grants zero. |
| P3 | Interstitial | Test unit loads/shows/closes and returns to the exact pre-ad game state. |
| P4 | Consumable | Android: internal-track purchase exposes `purchaseToken`; iOS: StoreKit 2 path exposes `Transaction.id`. In both: purchase -> verify -> grant -> durably store processed transaction key (FR-SAVE-08) -> consume/finish. Kill/relaunch once after purchase before grant and once after durable grant before consume/finish; no loss and no double grant. |
| P5 | Non-consumable + restore | Purchase, reinstall, query/restore/current entitlement; entitlement returns on both platforms and is never lost. |
| P6 | Analytics | Verify FR-CONSENT-02: events before consent are queued locally, then sent or dropped according to the result. Provider collection defaults remain disabled/denied until allowed. One named test event with expected params then appears in the dashboard. |
| P7 | Crash | Deliberate crash appears with `app_version`, `content_version` and a readable **GDScript stack** (script frames/lines via provider support or attached backtrace). Record native symbolication state (NDK symbols/dSYM) as evidence, not as the sole PASS condition. Crash collection starts on first launch without advertising identifiers when provider configuration permits FR-CONSENT-02; otherwise document why it must wait for consent. |
| P8 | Haptics | Light/tick feedback is felt when enabled and absent when disabled; iOS uses native impact/selection feedback. |
| P9 | Silent switch | iOS SFX is audible with switch off and silent with switch on. |
| P10 | Store upload | Android AAB accepted on internal track, target API 36, PBL 8+ and native 16 KB compatibility verified. iOS archive built with Xcode 26+/iOS 26 SDK, accepted by App Store Connect and installed from TestFlight. |
| P11 | Stability | 10-minute loop through ads plus purchase/query/restore completes without crash, ANR, hang or lost entitlement. |

## 5. Failure classification

**Stop / engine gate failure:** F1 any P1-P5 path lacks an existing maintained plugin and needs a
native ads/IAP plugin written or substantially rewritten; F2 documented ads/IAP setup reproducibly
crashes/hangs/loses a purchase (lost purchase always fails); F3 P10 store rejection for an
engine-level reason export settings cannot fix. F4 remains T-0029: engine-caused perceivable swipe lag.

**Record but do not fail Godot solely for it:** analytics provider failure with working HTTPS fallback;
Sentry or Crashlytics failure while another provider can satisfy P7; small iOS haptics bridge; raised
minimum OS; or an iOS UMP/ATT timing mismatch that requires a Chris-approved PRODUCT change.

## 6. Execution order

1. Complete the account/provider entry checklist and create test resources against the `.spike` ID only.
2. Pin exact plugin release/commit and native SDK versions.
3. Prove clean export/install, then execute P1 at the PRODUCT-defined slot boundaries.
4. Run P2-P3 ads, then P4-P5 purchases/restore including the two kill/relaunch durability cases.
5. Run P6 analytics and P7 against Sentry first; test Crashlytics as the bounded crash fallback if needed.
6. Run P8 haptics, and on iOS P9.
7. Run P10 through the real store test path, then P11 stability.
8. Capture exact failure evidence before using a listed fallback; otherwise escalate.
