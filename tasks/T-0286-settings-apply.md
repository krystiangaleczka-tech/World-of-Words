---
id: T-0286
title: Persist and apply caller-owned settings without optimistic effects
epic: E21
type: feat
area: features.settings
risk: high
executor: sol
think: high
ui: high
status: review
depends_on: [T-0285, T-0207]
touch:
  - game/services/settings_runtime.gd*
  - game/services/save.gd
  - game/services/audio.gd
  - game/services/haptics_listener.gd
  - game/features/settings/*.gd*
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_apply.gd*
  - docs/qa/T-0286/**
  - tasks/T-0286-settings-apply.md
  - tasks/T-0285-settings-screen.md
revision: 1
---

## Goal
Apply only committed display/audio/haptics choices and expose explicit retry.

## Current state
Merged T-0285 sends settings intent only. Save retains dirty failed values but
signals after flush. Existing Audio/HapticsListener read working settings; Audio
has SFX, no caller music binding. Six generated themes exist. Contract T-0284.

## Specification
Implement SettingsRuntime.configure(save,root), set_value, retry, snapshot and
changed/write_failed. One failed candidate at a time; exact retry; invalid/busy
writes don't alter applied state. Reject reentrant replacement. Bind screen
explicitly (bind_runtime), not boot/Nav. Screen resets controls to committed state
on error, shows translated retry; no reload or language mutation here.
Choose six existing themes from high_contrast/text_scale, apply Tokens.reduced_motion.
Implement three closed text-size Sheet options with catalog TextButton controls.
Save.configure_system_defaults(bool,language="pl") validates before-load injection;
only a fresh new document uses it. Existing/migrated/recovered settings unchanged.
No native OS observation is fabricated. Audio/HapticsListener consume committed
values, not failed dirty values. Audio.bind_music(player:AudioStreamPlayer)->Error
is explicit caller-owned volume/pause binding, never starts music or invents a track.
No save-format/config/schema/SDK/autoload changes. Reconcile merged T-0285 to done.

## UX rules
R-UI-1/2 existing catalog only; R-UI-3 tokens; R-UI-4 locale keys; R-UI-5 themes
unchanged; R-UI-6 native three classes PL/PSEUDO default/HC130 evidence. Reference
DESIGN.md#settings/#accessibility. Physical OS/device/taste gates, including the unmaterialized T-0228 iOS row, remain open.

## Tests
Actual Save failure/retry/other-flush/atomic-busy/reentry/reentrant replacement;
six themes, tokens, native toggles/slider release; actual Audio volume and bound
music, Haptics suppression; new-install defaults and existing-install preservation;
text-size Sheet/scroll/12-case matrix. Full checks, fresh review, all CI green.
