# T-0249 analytics/crash SDK preflight

Status: PREPARATION ONLY; T-0249 blocked pending provider inputs and actual native installation.
Audited application base:4c1a06cb709f475e0bd3881440bddcf925b782bf. Research:2026-10-14.
No SDK is installed, initialized or certified by this report. Existing Platform Fakes remain active.

## Inputs already established

- decision0009: Firebase Analytics via godot-x/firebase; Sentry2.x for readable GDScript crashes.
- decision0007: Android/iOS production ID com.mazen.worldofwordgame; .spike resources are separate.
- Godot4.7.2 ed1daf0bf; T-0208 fonts/theme and merged T-0248 naming review are present.
- S1 reports explicitly deferred provider P6/P7 and recorded missing provider resources at that time.
  No current Firebase/Sentry project readiness or CI secret availability is inferred from those reports.

## Upstream candidates

| Provider | Release / exact source commit | Published asset | Bytes | Published SHA-256 |
|---|---|---|---|---|
| Firebase |3.1.0 /188d9ed07876acca4900c7d98a0013e5b2bcf321 |godotx_firebase.zip |73075196 |da7273def2ff744efacaab70e2ad863d65a4225ec401f5335de40a19df8170c1 |
| Sentry |2.3.0 /8ec908376fd9ffb6349a2a564562d9b3f8255f14 |sentry-godot-2.3.0+8ec9083.zip |39578299 |f8de89d3860b00b19bf52eb3b9d66cd3ac3e5522a375e72f16f60672450c7417 |

These are observed release metadata, not independently calculated archive hashes or adopted pins.
A real acquisition step must verify downloaded bytes before extracting/using them.
Firebase's annotated3.1.0 tag resolves through2e57db624b68352bcabef29de7b0c3b8d51d2737 to the
source commit above. Sentry release target is the stated exact commit.

Sources:
- https://github.com/godot-x/firebase/releases/tag/3.1.0
- https://github.com/godot-x/firebase/blob/188d9ed07876acca4900c7d98a0013e5b2bcf321/README.md
- https://github.com/godot-x/firebase/blob/188d9ed07876acca4900c7d98a0013e5b2bcf321/addons/godotx_firebase/export_plugin.gd
- https://github.com/getsentry/sentry-godot/releases/tag/2.3.0
- https://github.com/getsentry/sentry-godot/blob/8ec908376fd9ffb6349a2a564562d9b3f8255f14/README.md
- https://github.com/getsentry/sentry-godot/blob/8ec908376fd9ffb6349a2a564562d9b3f8255f14/src/sentry/sentry_options.cpp

## Concrete integration requirements

Firebase3.1.0 documents Godot4.7, Android API24+, iOS13+, Firebase Analytics Android23.2.0,
Firebase iOS12.16.0 and Kotlin2.4.0. These are upstream compatibility claims, not this app's build
results; the application's iOS17 minimum remains unchanged. Its export plugin requires Gradle
builds, Core plus Analytics, and native AAR/XCFramework payloads. Keep firebase/privacy_safe_defaults
true: export inspection must show collection disabled and consent denied before GDScript runs.
Do not include optional Messaging; Sentry is the selected crash provider, so do not activate Firebase
Crashlytics by copying the README's full demo. Integrating source alone does not register real adapters.

Sentry2.3.0 documents Godot4.5+ and Android/iOS support. Its source defines
sentry/options/auto_init, sentry/options/dsn and sentry/options/send_default_pii, and supports a
SENTRY_DSN environment override. An environment variable on the build worker is not automatically
available inside a mobile app; the future sealed configuration step must provide the approved
runtime configuration explicitly. Disable auto_init and default PII until the consent/configuration
owner allows collection. An embedded GDExtension may load before GDScript; its startup path needs
actual clean-install inspection. Do not claim a readable script crash based only on the README.

## Provider inputs to resolve

| Input | Required match / handling | Current observation |
|---|---|---|
| Android Firebase config |google-services.json for com.mazen.worldofwordgame; injected via approved CI/local provider path, not committed |Unavailable; projects not created |
| iOS Firebase config |GoogleService-Info.plist for com.mazen.worldofwordgame; same controlled handling |Unavailable; projects not created |
| Sentry ingest configuration |Approved project DSN/environment/release routing through configured secrets/build input |Unavailable; projects not created |
| Symbol upload, if configured |Explicit project/org/token binding; no values in logs or repository |Not configured by this task |
| Android/iOS native setup |Gradle/export integration and Xcode/archive inspection against the exact acquired artifacts |Not executed |

Chris explicitly answered "Jeszcze nie są utworzone" on2026-10-14: Firebase/Sentry projects are
not yet created. The managed
runtime currently reports no secret bindings; this does not inspect or establish the state of GitHub
Actions secrets or the owner's local provider configuration. No credential files are read to discover
values. No store/provider resources are created.

## Owner setup checklist

1. Create/select the game's Firebase project, add Android and iOS apps with the exact production
   identity com.mazen.worldofwordgame, and obtain their google-services.json/GoogleService-Info.plist.
   Do not reuse .spike app entries; keep Android/iOS configuration associated with the same project.
2. Create the approved Sentry project and select its intended development/release environments.
   Retain its ingest DSN and symbol-upload configuration separately; the upload auth token is not
   a mobile runtime DSN and must not be bundled into the app.
3. Place configuration through the approved secret/file binding path for the later integration
   revision. Report project readiness and configured binding names only; never paste credential
   values into the task conversation or commit them to the public repository.
4. Resume T-0249 acquisition/integration on the exact SDK candidates above and inspect the builds.
   Project creation alone is not consent approval, SDK compatibility or P6/P7 dashboard evidence.

## Execution checklist when inputs exist

1. Verify both upstream asset digests locally; inventory licences and selected native dependencies.
2. Revise T-0249 with bounded plugin/project/export/CI touch; retain rollback and startup-disable checks.
3. Configure production app entries, inject provider files without committing them and verify identity.
4. Install selected modules without enabling collection. Prove clean-cache import and Android exports;
   inspect packaged collection defaults, native libraries and configuration inclusion/exclusion.
5. Build the iOS archive with the actual required toolchain and inspect frameworks/privacy resources.
6. T-0250/T-0252/T-0253 own consent-aware delivery/real adapters and dashboard/crash evidence;
   device P6/P7 are not replaced by an export test. Keep the SDK/provider/device status truthful.

## Validation

Upstream release/tag/readme/export-plugin/options sources inspected via GitHub; no binaries downloaded.
Task/scope lint and full repository checks are recorded in the preparation PR. A brief managed-runtime
transport outage occurred during research, then connectivity recovered; no installation was attempted.
