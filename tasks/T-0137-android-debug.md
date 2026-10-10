---
id: T-0137
title: Export a verified prototype Android debug APK in CI without upload secrets
epic: E09
type: infra
area: infra
risk: high
executor: cheap
think: high
ui: none
status: done
depends_on: [T-0022, T-0134, T-0135, T-0144]
touch:
 - game/export_presets.cfg
 - game/project.godot
 - game/assets/app_icon.svg*
 - game/features/debug/debug.gd
 - .github/workflows/ci.yml
 - .gitignore
 - tools/android_debug_build.py
 - tools/export_smoke.gd
 - tools/tests/test_android_export.py
 - docs/qa/T-0137-android-debug.md
 - tasks/T-0137-android-debug.md
revision: 1
---

## Goal
Deliver the P1 Android debug APK artifact and release resource filtering from the
ROADMAP row, using only a disposable public debug key. Chris explicitly said
T-0136 is not configured and to continue work possible without secrets. No
production upload key, GitHub signing secrets, store submission or release APK.

## Current state
Pinned CI image supplies Godot4.7.2, JDK17, AndroidSDK/build-tools36, export
APK templates. A scratch export preflight confirmed Android additionally requires
ETC2/ASTC texture imports enabled and a launcher icon configured. Project already uses Compatibility renderer and portrait (1).
No main game export_presets.cfg or Android CI job exists. Boot discovers imported
translations, loads registry JSON/WAV and dynamically owns debug tools. Debug
screen still opens raw CSV, which is not available in default resource exports.
T-0051 phase exit and T-0136 remain unperformed human gates. This authorized
prototype continuation uses actual technical dependencies without claiming them.

## Specification
1. Explicit S7/S11 scope: add Android Debug/Release export presets. Use normal
   APK templates (no Gradle/plugins/network downloads), explicitly enable
   rendering/textures/vram_compression/import_etc2_astc for Android-compatible
   texture import, supply a provisional original SVG launcher icon and configure
   application/config/icon (required by Android exporter), arm64, portrait existing
   project setting. Pinned templates have minAPI24/target36; do not override
   Gradle-only SDK fields. Both presets enable VIBRATE and INTERNET as the ROADMAP
   requires; no extra custom permissions or endpoints. Temporary prototype
   identifiers org.worldofwords.prototype.debug and org.worldofwords.prototype
   are separate from S1 diagnostic data and are not a final store identity.
2. Both export all resources plus raw JSON and exclude tests/GUT. Debug retains
   developer tools/gallery; release has no custom debug tag and excludes
   features/debug, ui/gallery and the Level gallery helper. Keep production
   keystore fields empty. Ignore engine export_credentials.cfg; keys remain
   outside the repository. T-0138 checks actual exported release contents.
3. tools/android_debug_build.py verifies exact Godot version, creates a disposable
   public Android debug key (standard public password), isolated editor settings
   and optional template path. Import/export Android Debug, verify APK CRC/assets,
   binary manifest (package,min24,target36,portrait,exact VIBRATE/INTERNET), and
   apksigner. Write a verification report. No release export/signing secret access.
4. Replace Debug raw-CSV registration with independent imported PL/EN copies;
   preserve translation ownership, behavior and all prior debug tests. Include a
   typed external export smoke script exercising real packaged boot, audio,
   developer route/copy and return to Level. No gameplay/core/save changes.
5. Add android-build CI job after existing game/content/registry checks, using
   the pinned toolchain image, without custom secrets. Upload verified debug APK
   and report via upload-artifact@v4. Build/report failures fail CI. Document local
   invocation, artifact download, disposable-key reinstall limitation and human
   device QA still required. No APK, keystore or generated build cache committed.

## Tests
Tools regressions: reject wrong manifest package, SDK versions, debug flag,
portrait and extra/missing permissions; reject missing content/audio/developer
resources, test-code leakage and corrupt APK ZIP. Existing debug translation and
ownership tests stay green. Actually build/verify APK locally with pinned Godot
and SDK, export a debug resource ZIP and run packaged boot/debug/audio smoke.
Full make check, scope/task lint, fresh review and all 11 CI jobs including APK.
No Android runtime/device or production signing claim.

## Acceptance
A verified debug APK is downloadable from CI without T-0136. Release filtering
is configured; production release signing and human gates remain open.

## Rollback
Revert presets/build tool/job together; no saved data or existing user app identity
is migrated. Remove local build artifacts if needed.
