---
id: T-0284
title: Freeze Save-owned settings and explicit apply hooks
epic: E21
type: contract
area: features.settings
risk: high
executor: sol
think: med
ui: none
status: review
depends_on: [T-0229, T-0207]
touch:
  - docs/contracts/settings.md
  - tasks/T-0284-settings-contract.md
  - tasks/T-0285-settings-screen.md
  - tasks/T-0286-settings-apply.md
  - tasks/T-0287-language-selector.md
  - tasks/epics/E21-settings.md
revision: 1
---

## Goal
Freeze the existing Save setting owner and the explicit interfaces required by the
next three E21 tasks, without creating an autoload or activating a screen.

## Context
Roadmap T-0284; ARCHITECTURE.md#autoloads, FR-SET-04; DESIGN.md#accessibility.
Phase-2 rolling-wave rule permits this four-task wave on current main.

## Current state
Save.get_setting/set_setting and setting_changed exist over seven closed keys.
set_setting retains dirty values on failure but emits only after successful flush.
Audio reads live volumes; HapticsListener reads haptics_enabled. Six generated
combinations (default/HC x100/115/130) exist; no Settings screen/apply owner exists.

## Specification
Document exact existing accessors, copied committed snapshots, finite caller retry,
failure/reentry behavior, runtime hook ownership and first-install system-default
injection. Freeze SettingsScreen.configure(save), SettingsRuntime.configure(save,
root) and initial Save defaults for later tasks. System providers are injected;
unsupported native OS motion observation is never fabricated. Existing installs
retain explicit preferences. Language requires shipped content; EN UI preview is
transient debug-only. Materialize T-0285/86/87 with bounded scopes/tests.

## Tests
Verify every cited API/path and generated theme variant. Full make check, scope,
fresh independent review and all CI. No runtime code, save format, Nav or SDK change.
