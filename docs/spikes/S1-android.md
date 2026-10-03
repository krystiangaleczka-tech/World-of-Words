# S1 Android execution report — T-0027

Date: 2026-10-03. **Task: DONE by Chris acceptance; full S1 matrix: DEFERRED / NOT EXECUTED.**
Chris confirmed provider/store resources are not prepared. This round performs the available
export/device preflight only. Chris closed T-0027 on 2026-10-03 with the remaining tests deferred.
T-0028/T-0033 must not interpret task completion as an S1 matrix pass.

## Trace to T-0026

PR #8 merged at 9749479 after review fixes F1-F9. Its task file still says `review`; the merged
plan and accepted decision 0007 are the inputs, with no modification of those documents.
Roadmap dependency T-0012 has no task file yet and store/account readiness is unconfirmed.
The local T-0027 file records T-0026 as its machine-readable dependency; the missing T-0012
and plan section 2 entry checklist remain prerequisites for the deferred tests, not evidence that those tests passed.

## Environment and pins

- Godot editor/export templates: `4.7.2.stable.official.ed1daf0bf`, standard build.
- Device: Samsung Galaxy A15 5G `SM-A156B` / `a15x`; Android 16, API 36.
- Disposable package: `com.mazen.worldofwordgame.spike`; debug build 0.1.0 / code 1.
- Java 17.0.18; Android SDK/build tools 36; arm64-v8a; min API 24, target API 36.
- Poing AdMob **v5.1.0**, matching `android-template-v4.7.2.zip`.
- Native ads dependency: `ads-mobile-sdk:1.4.0`; UMP **4.0.0** from APK properties.
- Play Billing plugin **3.3.0**, native `billing-ktx:9.1.0` (also verified in APK manifest).
- Analytics/crash/haptics plugins not installed yet; no fallback attempt or provider failure claimed.
- Upstream download URLs and archive SHA-256 are pinned in `spikes/s1-android/setup.sh`.
- APK SHA-256: `dbd2abcb6f1d7114de79033b354aff9ce2cab428c053630f3c0cd16bf1a6b104`.

Sources: [Godot release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable),
[Poing release](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0),
[Billing release](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.3.0).

## Preflight evidence

- `make check`: PASS; GUT 1/1, pipeline pytest 2/2, tools pytest 30/30.
- Diagnostic headless import: PASS. gdformat/gdlint and shell syntax check: PASS.
- Debug APK export: PASS after enabling ETC2/ASTC texture imports and adding a diagnostic icon.
- `aapt dump badging`: package `.spike`, minSdk 24, targetSdk 36, arm64-v8a.
- `zipalign -c -P 16 -v 4`: `Verification successful`.
- Both packaged native libraries (`libgodot_android.so`, `libc++_shared.so`) have ELF LOAD
  alignment `0x4000` (16 KB). These APK checks do not replace AAB/internal-track evidence for P10.
- Merged permissions include INTERNET, AD_ID, ACCESS_NETWORK_STATE, READ_BASIC_PHONE_STATE,
  Google AD_ID, BILLING, WAKE_LOCK, FOREGROUND_SERVICE and the app-specific dynamic-receiver permission.
  Production permissions/declarations must be evaluated separately against the final SDKs.
- Upstream Gradle template warns AGP 8.6.1 was tested through compileSdk 35; export with 36 succeeds.
- Install: `adb install -r` returned `Success`. Launcher is `com.godot.game.GodotAppLauncher`.
- 22:07:14 logcat: Godot 4.7.2 official; `Engine.has_singleton` returned true for AdMob,
  ConsentInformation, RewardedAd, InterstitialAd and GodotGooglePlayBilling.
- 22:07:14.674 logcat: `S1: Billing connected (smoke only)`. No purchase flow was launched.
- [Device screenshot](../../spikes/s1-android/evidence/device.png) visually verified; no script
  errors or fatal exception in captured app-process logcat. This is startup evidence only.
- Local full check/export/import logs are under `/tmp/wow-s1/`; APK remains in ignored
  `spikes/s1-android/export/s1.apk`. setup.sh reproduces dependencies without committing binaries.

## P1-P11 results

DEFERRED means not executed, never a pass/fail inference from mocks or a sideloaded smoke run.

| ID | Result | Evidence still required |
|---|---|---|
| P1 Consent | DEFERRED | Real `.spike` AdMob app/published UMP; form after slot 1, GDScript state, init ordering |
| P2 Rewarded | DEFERRED | Consent-compliant Google test unit; full-watch callback exactly once, early close zero |
| P3 Interstitial | DEFERRED | Consent-compliant test unit and exact pre-ad state restoration |
| P4 Consumable | DEFERRED | Internal-track/tester/product, verify/grant/durable token/consume and both kill points |
| P5 Restore | DEFERRED | Non-consumable purchase, reinstall and entitlement recovery through Play |
| P6 Analytics | DEFERRED | Firebase config/dashboard, denied defaults, queue send/drop and named event params |
| P7 Crash | DEFERRED | Sentry project/DSN, version tags, readable GDScript stack and symbolication evidence |
| P8 Haptics | DEFERRED | First-choice haptics plugin installed; Chris feels enabled light/tick and no disabled tick |
| P9 Silent switch | N/A | iOS-only; T-0028 owns this row |
| P10 Store upload | DEFERRED | Signed AAB accepted on internal track plus AAB SDK/16 KB evidence |
| P11 Stability | DEFERRED | Real 10-minute ads/purchase/query/restore cycle; no crash, ANR, hang or lost entitlement |

## Deferred validation checklist

1. Complete T-0012 account/payment/tester prerequisites and S1-plan section 2 provider resources.
2. Keep configs/signing secrets local, never in this report or Git; preserve the `.spike` identity.
3. Extend this diagnostic project to the actual plan matrix, including durable receipt verification
   and the two interruption points, consent queue, crash tagging and haptics.
4. Run P1-P8/P10/P11 with device/store/dashboard evidence before release; update matrix results
   in follow-up validation work. T-0027 remains done under Chris's accepted scope.

## Classification

No F1/F2/F3 determination is possible from this round. Missing accounts are an entry prerequisite
dependency for deferred validation, not evidence against Godot. No production code, production resources or original docs changed.

## Completion decision — 2026-10-03

Chris accepts the available diagnostic/device results and closes T-0027. Play account registration
and real purchase/restore/store-upload validation move closer to release. The other unexecuted
matrix rows remain visible above and must be covered in follow-up validation before publication.
Gameplay, input, save, performance and haptics checks continue during development without waiting
for Play. The accepted risk is later discovery of SDK/store incompatibility and possible rework;
no change to decision 0001's pass criteria or an accepted engine-gate outcome is implied.
