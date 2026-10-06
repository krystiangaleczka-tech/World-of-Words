# 0009 — Platform providers and minimum OS versions

- Status: accepted (T-0033, 2026-10-06). Chris explicitly approved Godot 4.7.2 with the residual
  deferred SDK/store validation risk accepted for development; validation remains required before release.
- Engine: Godot 4.7.2 standard build, typed GDScript.
- Evidence: S1-plan, S1-android, S1-ios and S2-swipe. Repository preparation and human swipe evidence
  are distinct from the deferred SDK/store matrix; no deferred row is a PASS.

## Decision

| Capability | Selected path | Bounded fallback / boundary |
|---|---|---|
| Ads, UMP, ATT | Poing Studios Godot AdMob; S1 pin 5.1.0 | Community godot-admob from S1-plan after a documented first-choice failure; no new native ads implementation |
| Android IAP | godot-sdk-integrations/godot-google-play-billing, S1 candidate >= 3.3.0 | No unproven alternative; escalate if no maintained plugin satisfies durable purchase semantics |
| iOS IAP | OpenIAP godot-iap; S1 pin 3.6.2, StoreKit 2 | Only an upstream StoreKit 2 alternative exposing Transaction.id and explicit finish-after-durable-grant |
| Analytics | godot-x/firebase Analytics | Provider-independent HTTPS adapter after a separate implementation task |
| Crash reporting | getsentry/sentry-godot 2.x | Firebase Crashlytics only after the same readable-GDScript-stack proof; HTTPS reporting is allowed only if it satisfies P7 |
| Haptics | toniqat/godot-haptics, S1 source candidate 75cf71c6b0ea0db6a7023009240391dadd2c3710 | Small native iOS impact/selection bridge; device proof still required |

These selections freeze the architecture choices from S1, not SDK installation or proof of compatibility.
Production integration tasks pin exact builds and native dependencies; none is installed by this decision.

## Minimum operating systems (Q9)

- Android: API 24 / Android 7.0 minimum, driven by the selected Firebase integration.
- iOS: iOS 17 minimum, driven by OpenIAP's selected prebuilt framework.
- Minimum OS versions are distinct from store target API and build-SDK requirements.
- No lowest-supported-OS device validation is claimed. NFR-09 requires that evidence before release;
  Galaxy A15 and iPhone 13 Pro Max preparation do not prove it.

## Consent, durability and collection boundaries

PRODUCT remains canonical: UMP after slot 1 where required; the iOS ATT flow after slot 6.
SDK initialization and analytics collection must preserve the existing consent defaults and send/drop
queue behavior. This decision changes no consent or economy rule.

Purchases require the provider transaction key, verification, grant, durable storage of the processed
transaction, then consume/finish. Recovery must avoid both loss and duplicate grants. The deferred
kill/relaunch and restore tests remain mandatory before release.

Crash collection follows FR-CONSENT-02: no advertising identifiers; collection before consent is allowed
only where the selected configuration and the Q7/privacy decision permit it. Otherwise it waits for consent.

## Haptics and iOS audio

The production adapter must suppress all haptics when Settings disables feedback. Android's S2
Input.vibrate_handheld tick proves neither iOS native feedback nor the Settings-off contract.
The small iOS bridge is permitted by decision 0001 and is not an engine failure on its own.

Use an Ambient/default-style iOS audio session that respects the hardware silent switch; do not choose
Playback for game SFX. Audible/silent behavior and interruption recovery need actual iPhone validation.

## Mobile accessibility

On the pinned engine path, TalkBack/VoiceOver label exposure is not treated as supported.
Keep accessibility label keys required by FR-A11Y-04; mobile exposure stays in Later until a supported
engine/native path is established. No full gameplay support for blind players is claimed.

## Gate evidence and deferred work

- T-0028: merged PR #10; task done under Chris's accepted repository-preparation scope.
  iOS P1–P11 remain DEFERRED / NOT EXECUTED.
- T-0029: merged PR #12. On 2026-10-06 Chris confirmed the Galaxy A15 test was performed and reported
  smooth swipe. F4 was not observed in that human assessment; numeric latency/FPS and detailed
  haptics/backtrack observations were not supplied.
- Android S1 records repository/export/plugin preparation; its deferred provider/store matrix is not PASS.
- F1–F3 have no recorded engine failure, but the deferred matrix does not demonstrate their absence.

Before release, execute the outstanding Android/iOS P1–P11 matrix, store upload/native compatibility
checks, lowest-supported-OS validation and detailed production swipe/haptics QA. Reopen decision 0001
if F1–F4 is established. Chris explicitly accepted the residual integration risk on 2026-10-06 and authorized continued
development on the Godot path. This is not a release approval.

## Revisit if

- Any F1–F4 engine failure is established, or a maintained ads/IAP plugin needs substantial native rewriting.
- A selected SDK changes the minimum OS or cannot satisfy existing consent/durability requirements.
- Store requirements or mobile accessibility support require a new engine decision.
