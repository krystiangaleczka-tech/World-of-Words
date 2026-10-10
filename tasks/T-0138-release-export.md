---
id: T-0138
title: Inspect the actual Android Release resource export in CI
epic: E09
type: infra
area: ci
risk: high
executor: cheap
think: high
ui: none
status: done
depends_on: [T-0137, T-0134]
touch:
 - tools/check_release_export.py
 - tools/tests/test_release_export.py
 - .github/workflows/ci.yml
 - docs/qa/T-0138-release-export.md
 - tasks/T-0138-release-export.md
revision: 1
---

## Goal
Enforce docs/PRODUCT.md#fr-debug-debug-tools FR-DEBUG-06 on a fresh actual Android Release
resource ZIP exported by pinned Godot, not by reading export preset text alone.

## Current state
T-0137 supplies Android Debug/Release presets, Godot4.7.2, JSON inclusion and
release exclusions for features/debug, ui/gallery, features/level/gallery and
GUT/tests. T-0134 implements guarded developer Level tools. CI has 11 jobs,
including verified debug APK export. The pinned Docker image installs templates
at /root/.local/share/godot/export_templates/4.7.2.stable, whereas Actions changes
HOME. Godot --export-pack supports unsigned ZIP exports with converted .gdc,
.scn and .remap resources, ECFG project.binary and exported class cache.
A preflight actual release resource export contained 184 files with the expected
exclusions, remaps and class cache. Inert debug translation data and guarded
shared Boot/Nav APIs remain; dedicated developer code and screens do not.

## Specification
1. Add a stdlib tools/check_release_export.py CLI inspecting a ZIP and optionally
   producing it freshly with --export and --godot. Assert pinned 4.7.2.stable,
   import then --export-pack "Android Release". Remove stale output before export;
   engine ERROR or failed subprocess must fail even if a previous valid ZIP exists.
2. Inspect actual ZIP entries/CRC; reject duplicate/noncanonical paths and
   features/debug/, ui/gallery/, features/level/gallery.* plus tests/ and
   addons/gut/ including compiled scripts/remaps. Require project metadata,
   exported class cache, Boot/Level scenes, PL manifest and audio registry.
3. Validate .remap destinations exist and are allowed. Reject compiled .gdc and
   .godot/exported resources with no allowed source remap, including hashed
   scenes. Validate class-cache resource paths point to shipped allowed scripts.
   Read ECFG property framing and the _custom_features string Variant; fail on
   custom debug tag or malformed metadata. Other property Variants need not be
   interpreted. Inert translation/config data and shared debug-guarded APIs are
   allowed, with no broad substring filter for the word debug.
4. Write a JSON report containing sorted actual files, count, custom features,
   policy identifier and archive SHA256. CLI failures are readable and nonzero.
5. Explicit infrastructure scope: add release-inspection CI job after existing
   format/lint/Godot tests, using pinned existing image. Configure XDG_DATA_HOME
   to the installed /root/.local/share templates and XDG_CONFIG_HOME to
   /root/.config SDK/JDK editor settings, without redefining HOME. Export
   and inspect unsigned Android Release resource ZIP and upload ZIP/report as
   world-of-words-release-content via upload-artifact@v4. No project/export
   settings changes, release APK, signing/upload secrets or custom dependencies.
6. Document commands/evidence and limitations. T-0136, T-0051 human gate, Android
   device QA and FUN GATE remain unperformed; user authorized continuation without
   secrets. This is resource-content inspection, not production signing/runtime QA.

## Tests
Accept genuine release shape with compiled remaps and harmless debug translations;
report exact list/hash. Reject developer roots/scripts/scenes/bytecode, debug
feature in binary metadata, malformed metadata, missing/corrupt/duplicate ZIP,
noncanonical paths, forbidden/missing remap and class-cache targets, orphan compiled
resources, missing required resources, wrong engine and export errors with stale
output. Actually export and inspect Android Release locally and in CI.
Full make check, scope/task lint, fresh independent review and all 12 CI jobs green.

## Acceptance
CI fails when actual release resources contain dedicated developer code/screens or
custom debug feature. Downloadable unsigned ZIP and report identify checked content.

## Rollback
Revert inspector/tests/job; no app data, runtime or signing configuration changes.
