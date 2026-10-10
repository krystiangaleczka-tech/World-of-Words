# T-0137 — prototype Android debug export

Android Debug/Release use pinned Godot 4.7.2 APK templates without Gradle or SDK
plugins. Templates provide min API24 / target36; SDK override fields are empty
because Godot permits them only with Gradle. The actual debug binary manifest
is checked for min24/target36, portrait and exactly INTERNET/VIBRATE. Both presets
explicitly enable these ROADMAP permissions. Existing portrait/Compatibility
settings are retained; mobile ETC2/ASTC import is enabled as the exporter requires.
An original SVG W mark in the P1 palette is a provisional launcher icon, required
by the exporter; it is not accepted final branding.

The temporary packages org.worldofwords.prototype.debug and
org.worldofwords.prototype are separate from S1 diagnostics and are not final
store identifiers. The debug APK includes developer tools and imported copy;
release excludes dedicated debug/gallery resources and has no custom debug tag.
Tests/GUT are excluded from both; raw JSON is included for config/content/audio.
T-0138 inspects the actual release resource ZIP, not merely these filter strings.
Debug screen now registers independent imported PL/EN resources, which work in
exports; raw CSV sources are not required at runtime.

Build tool verifies exact engine version, imports and exports to a requested
output with isolated editor settings and a disposable public Android debug key.
It checks APK CRC/assets, binary manifest and apksigner, then exports a resource
ZIP and runs actual packaged boot/audio/developer route/PL-copy/return-to-Level
smoke. The headless smoke injects the existing cue sink: loaded WAV/registry
requests are verified without requiring a speaker or active mixer at fast exit.
Engine errors and nonzero command statuses fail with captured diagnostic output.
No production upload key or GitHub custom signing secret is accessed/changed.

## Local reproduction

```
ANDROID_HOME=/path/to/android-sdk JAVA_HOME=/path/to/jdk \
  uv run python tools/android_debug_build.py --godot /path/to/godot \
  --templates /path/to/4.7.2.stable --output builds/world-of-words-debug.apk
```

In the toolchain image, ANDROID_HOME/JAVA_HOME/templates are already installed:
`uv run python tools/android_debug_build.py`. CI uses image JDK17. Local export
used the identical pinned Godot/Android templates and SDK/build-tools36, with
installed host JDK21; CI is the pinned JDK17 validation.

CI job `Android prototype debug APK` uploads `world-of-words-android-debug`
(APK + verification report), retained14days. Download from the corresponding
Actions run. Local reviewable APK: /workspace/artifacts/world-of-words-debug.apk.
No APK/keystore/cache is committed. Godot export_credentials.cfg is ignored.

A new disposable debug certificate is generated per build; APKs from different
builds cannot update each other. Uninstalling the prototype permits installation
but removes its local save. Keep the same build during a playtest. Production
signing/upload-key management belongs to unperformed T-0136/T-0315.
Android installation, swipe/audio/haptics/device comfort and human fun gates are
unperformed; headless desktop resource smoke is not Android runtime evidence.
T-0051 and T-0136 remain open. The user explicitly authorized continuation of work
possible without secrets; ROADMAP and human task status were not rewritten.

Validation: actual APK build, asset/manifest/signature checks and packaged resource
smoke passed without engine errors. Full make check passed:218 GUT/8,524 assertions,
199 pipeline and 103 tools tests. Scope/task lint pass.
Fresh independent review approved 01cc84dff866f1273f842eee3cbc5c0a112411ad; no blockers.
Reviewer independently verified actual APK/manifest/signature/resources and 16
focused tools tests. CI JDK17 Android build remains required before merge.

### CI template-path correction

The first APK job exposed that Actions replaces HOME with /github/home, while
the pinned image installs templates under /root/.local/share. The job now passes
that exact installed template directory explicitly to the existing --templates
option, which links it into isolated XDG data. No image, key or engine change.

Fresh reviewer approved CI correction at 5b1d80bf705dc783f4e5f50b135f1c0dc5bf5b05;
full make check and scope passed. Merge requires rerun of all 11 CI jobs green.
