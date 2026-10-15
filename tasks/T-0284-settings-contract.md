---
id: T-0284
title: Define the validated Settings accessor and apply hooks
epic: E21
type: contract
area: features.settings
risk: high
executor: sol
think: med
ui: low
status: review
depends_on: [T-0229, T-0207]
touch:
  - game/features/settings/settings_controller.gd*
  - game/tests/integration/test_settings_controller.gd*
  - tasks/T-0284-settings-contract.md
revision: 1
---

## Goal
One validated way for Settings UI and boot code to read, change and apply the closed settings
set, without a new autoload. Owner asked to continue with the next roadmap task.

## Context
- ARCHITECTURE.md#autoloads — "Settings are owned by `Save`, so no new autoload is needed."
  `Save.get_setting` / `set_setting` persist immediately and emit `setting_changed(key)`.
- DESIGN.md#accessibility — "`Tokens.reduced_motion` is set at boot from the save"; the matching
  `theme_<default|hc>_<100|115|130>.tres` is applied to the root window; reduced motion "default
  follows OS setting where the platform exposes it".
- FR-SET-04, FR-A11Y-02, FR-A11Y-03. Roadmap T-0284.

## Current state
- `Save.get_setting/set_setting` and `SaveSchema.SETTINGS` (sfx_volume, music_volume,
  haptics_enabled, reduced_motion, high_contrast, text_scale, language) exist.
- `Audio` and `HapticsListener` already re-read volume / haptics from Save live.
- `Tokens.reduced_motion` is a static bool; six theme variants exist in `ui/theme/generated/`.
- `game/features/settings/` does not exist yet.

## Specification
1. `SettingsController` (RefCounted) wraps an injected Save. `set_value(key, value)` validates the
   type and range before delegating: volumes float in 0..1, booleans bool, text_scale int 0..2,
   language non-empty String. Unknown key -> ERR_INVALID_PARAMETER, bad value -> ERR_INVALID_DATA,
   unbound -> ERR_UNCONFIGURED. Nothing is written on a rejected value.
2. `get_value(key)` returns the stored value (null for unknown or unbound).
3. `theme_path(high_contrast, text_scale)` is pure and maps to one of the six generated themes;
   an out-of-range scale falls back to 100.
4. `bind(save, theme_sink, os_reduced_motion)` connects `setting_changed` and runs `apply_all()`.
   `apply_all()` sets `Tokens.reduced_motion` and calls `theme_sink(path)`. Each later
   `setting_changed` re-applies; `unbind()` disconnects. Volumes and haptics need no hook.
5. OS default: `os_reduced_motion` returns 1, 0 or -1 (not exposed). Effective reduced motion is
   the stored value OR an OS value of 1.

## Out of scope
Settings screen, language switching, save schema, config keys, new strings.

## Tests
`game/tests/integration/test_settings_controller.gd`: validation matrix; persistence and signal;
theme_path table; bind applies, re-applies on change and stops after unbind; OS default.

## Deviations / concerns
The schema has no unset state for `reduced_motion`, so an OS value of 1 cannot be overridden off
by the player. A tri-state setting needs a save-schema change (S6) and is left to the owner.

## Rollback
Delete the unused controller.

## Escalation log
