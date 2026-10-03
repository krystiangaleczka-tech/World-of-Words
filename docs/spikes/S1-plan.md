# S1 platform SDK spike plan

Research snapshot: **2026-10-03**. Engine under test: **Godot 4.7.2 standard build, typed GDScript**.
This plan turns decision 0001 P1-P11/F1-F4 into device work for T-0027 (Android) and T-0028 (iOS).
No SDK is installed by T-0026.

## 1. Outcome of the plugin survey

### Ads, UMP and ATT

**First choice: Poing Studios Godot AdMob plugin, current stable release at S1 execution time.**

Why:
- the project documents native Android + iOS support for Godot 4.5+;
- UMP is documented, including consent-info refresh on every launch;
- its iOS guide covers the UMP IDFA explainer / ATT flow;
- active development continued through September 2026.

Sources:
- https://github.com/poingstudios/godot-admob-plugin
- https://poingstudios.github.io/godot-admob-plugin/latest/privacy/user_messaging_tools/get_started/
- https://poingstudios.github.io/godot-admob-plugin/5.0/privacy/user_messaging_tools/idfa_support/

**Fallback: godot-sdk-integrations/godot-admob v7.x.**

It provides one GDScript interface across Android/iOS, rewarded/interstitial callbacks, UMP and ATT
signals. However, an open 2026 issue reports v7.0 failing to initialize on Godot 4.7, so it is a
fallback rather than the first S1 attempt.

Sources:
- https://github.com/godot-sdk-integrations/godot-admob
- https://github.com/godot-sdk-integrations/godot-admob/issues/124

Rule for T-0027/T-0028: one documented setup attempt with the first choice; if an integration-specific
failure remains after checking the plugin's documented setup, retry the fallback. Do not patch native
ads code beyond a small compatibility fix.

### Android Play Billing

**First choice: godot-sdk-integrations/godot-google-play-billing.**

The maintained master line documents Godot 4.2+ support and uses Gradle export. This is the dedicated
Android candidate for consumable, non-consumable and restore testing.

Source:
- https://github.com/godot-sdk-integrations/godot-google-play-billing

No second Android billing plugin is required before S1. If this plugin cannot expose purchase tokens,
consume/acknowledge correctly or restore entitlement without substantial native rewriting, record F1/F2.

### iOS StoreKit 2

**First choice: godot-sdk-integrations/godot-storekit2.**

It is the dedicated StoreKit 2 integration in the Godot SDK Integrations organization. Its README
explicitly says the API is still under development and may contain bugs; that is the principal S1 risk.

Source:
- https://github.com/godot-sdk-integrations/godot-storekit2

**Fallback: OpenIAP Godot plugin 2.x.**

OpenIAP supplies StoreKit 2 on iOS and Play Billing on Android, but its current prebuilt iOS package
requires iOS 17+ and its docs note noisy iOS-only GDExtension discovery on Godot 4.7. It is acceptable
as a bounded fallback, but adopting it would raise the deployment floor and must be recorded for Q9.

Sources:
- https://www.openiap.dev/docs/setup/godot
- https://github.com/hyochan/godot-iap (archived predecessor; development moved to OpenIAP)

**Rejected for S1: godot-sdk-integrations/godot-ios-plugins InAppStore.**
Its current InAppStore path is StoreKit 1, while S1 explicitly requires StoreKit 2.

Sources:
- https://github.com/godot-sdk-integrations/godot-ios-plugins
- https://github.com/godot-sdk-integrations/godot-ios-plugins/issues/57

### Analytics and crash reporting

**First choice for S1: godot-x/firebase, Analytics + Crashlytics modules.**

The project currently declares Godot 4.7-stable compatibility, Android + iOS native modules,
Firebase Analytics and Crashlytics, prebuilt AAR/XCFramework artifacts, Android min SDK 24 and iOS
min 13. It also documents privacy-safe defaults that keep collection disabled before runtime consent.

Source:
- https://github.com/godot-x/firebase

This single candidate lets S1 verify both P6 and P7 while also checking consent-sensitive startup.

**Analytics fallback: plain HTTPS event delivery (PostHog-style capture endpoint or GA4 Measurement
Protocol behind the Analytics adapter).**

The fallback must prove only the app's required custom event path; it does not need a native Godot
plugin. Firebase's Measurement Protocol supports app-event POSTs, but if campaign attribution /
Firebase audiences are later required, the native SDK remains preferable.

Sources:
- https://firebase.google.com/codelabs/firebase_mp
- https://posthog.com/docs

**Crash alternative: Sentry only if an existing maintained Godot/mobile integration is available at
implementation time.** No maintained, clearly supported Godot 4.7 Android+iOS Sentry plugin was found
in this survey. A raw HTTP error endpoint is not equivalent to native crash capture, symbolication and
a readable native stack, so Sentry-over-HTTP is not a P7 substitute.

Per decision 0001, analytics or crash-provider failure alone does **not** fail the engine gate. Record
the provider failure and choose another adapter/provider later.

### Native haptics

**First choice for S1: toniqat/godot-haptics.**

It exposes iOS UIFeedbackGenerator impacts/selection feedback, Android vibration effects, an enabled
toggle and Godot 3/4 builds. This is sufficient for P8's "light tick" and off-state test.

Source:
- https://github.com/toniqat/godot-haptics

Fallback: a tiny iOS-only UIImpactFeedbackGenerator bridge is explicitly allowed by decision 0001 and
does not fail the engine gate. Do not expand that exception to ads or IAP.

## 2. Platform floors and store constraints to verify

- Google Play: new apps/updates submitted from 2026-08-31 must target Android 16 / API 36 or higher.
  Source: https://support.google.com/googleplay/android-developer/answer/11926878
- 16 KB pages: Godot has supported 16 KB Android pages out of the box since 4.5; nevertheless every
  native SDK in the exported AAB must be checked because plugins can bundle their own native libraries.
  Google Play's current enforcement deadline for updates targeting API 35+ is 2027-02-01.
  Sources:
  - https://godotengine.org/releases/4.5/
  - https://developer.android.com/guide/practices/page-sizes
- Apple: third-party SDK privacy manifests/signatures and the app's privacy declarations must match
  the actual embedded SDKs. Invalid privacy manifests can reject an App Store submission.
  Sources:
  - https://developer.apple.com/support/third-party-SDK-requirements/
  - https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- ATT: tracking/IDFA access requires authorization; S1 must exercise both allow and deny outcomes.
  Source: https://developer.apple.com/app-store/user-privacy-and-data-use/

## 3. Identifiers used by S1

Production identity (reserved, do not use for throwaway builds):
- Android: `com.krystiangaleczka.wordgame`
- iOS: `com.krystiangaleczka.wordgame`

S1 throwaway identity:
- Android: `com.krystiangaleczka.wordgame.spike`
- iOS: `com.krystiangaleczka.wordgame.spike`

Decision record: `docs/decisions/0007-app-identifiers.md`.

## 4. Ordered S1 test matrix

Run Android first in T-0027. Only after its report is committed does T-0028 repeat the applicable rows
on iPhone. Keep one row per attempt with: plugin/tag or commit, Godot version, OS/device, exact result,
dashboard/store evidence reference and PASS/FAIL.

| ID | Test | Android evidence | iOS evidence | Pass condition |
|---|---|---|---|---|
| P1 | Consent | UMP debug geography where needed; result readable in GDScript; ads init after resolution | UMP + IDFA explainer, then ATT allow and deny on clean installs | no ad SDK init before consent resolves; status readable |
| P2 | Rewarded | Google test rewarded unit; full watch and early close | same | reward callback grants exactly once; early close grants zero |
| P3 | Interstitial | Google test unit; open/close around a known game state | same | closes cleanly and resumes the same state |
| P4 | Consumable | Play internal-track product; purchase → grant → consume; capture purchaseToken | StoreKit sandbox product; purchase → grant → finish; capture Transaction.id | stable transaction key reaches GDScript; no double grant |
| P5 | Non-consumable + restore | purchase, reinstall, query/restore entitlement | purchase, reinstall, current entitlements/restore | entitlement returns after reinstall; no lost purchase |
| P6 | Analytics | emit one named test event after consent | same | event visible in provider dashboard with expected params |
| P7 | Crash | deliberate native/process crash in a tagged test build | same | report appears with app/content version and readable stack |
| P8 | Haptics | light/tick feedback, then disabled | native iOS impact/tick, then disabled | feedback felt when on; none when off |
| P9 | Silent switch | N/A | play SFX with silent switch on/off | SFX respects the hardware silent switch |
| P10 | Store upload | AAB accepted on internal track; inspect target API 36 and native libs/page alignment | archive accepted by App Store Connect and installs through TestFlight | no engine/plugin store rejection |
| P11 | Stability | 10 min loop through ads + purchase/query/restore paths | same | no crash, ANR, hang or lost entitlement |

Additional evidence required beside P1-P11:
- record plugin exact version/commit and native SDK versions;
- record min Android/iOS version implied by each selected plugin;
- record exported Android target SDK and min SDK;
- record whether every iOS SDK ships a valid privacy manifest where required;
- record cold-start behavior with analytics/crash collection disabled before consent;
- Android: inspect AAB native libraries for 16 KB compatibility;
- iOS: repeat ATT testing from a clean install because the system prompt is one-shot.

## 5. Failure classification

### Engine-gate failure — stop and escalate to T-0033

- F1: any P1-P5 path cannot pass with an existing maintained plugin; ads/IAP would require writing or
  substantially rewriting a native plugin.
- F2: a documented ads/IAP setup reproducibly crashes, hangs or loses a purchase. Lost purchase is
  always failure.
- F3: Play/App Store rejects P10 for an engine-level reason export settings cannot fix.
- F4 remains owned by S2/T-0029: perceivable swipe latency caused by the engine.

### Record, but do not fail Godot solely for this

- Firebase Analytics plugin fails but HTTPS analytics works.
- Crashlytics plugin fails; another crash provider must be chosen later.
- Native haptics needs a small iOS bridge.
- A candidate raises the minimum supported OS; record it for Q9/T-0033.
- A plugin-specific bug is fixed by switching to the bounded fallback without changing game APIs.

## 6. Execution order for T-0027 and T-0028

1. Create provider/store test resources against the `.spike` identifier only.
2. Pin the exact plugin release/commit in the spike report before testing.
3. Prove clean export/install with no SDK calls.
4. P1 consent before loading any ad.
5. P2-P3 ads.
6. P4-P5 purchases and restore.
7. P6-P7 analytics/crash.
8. P8 haptics; iOS also P9.
9. P10 upload/install through the real store test path.
10. P11 10-minute stability loop.
11. If the first-choice plugin fails, capture the exact error before trying the listed fallback.
12. Do not invent a third ads/IAP candidate inside T-0027/T-0028. Escalate instead.
