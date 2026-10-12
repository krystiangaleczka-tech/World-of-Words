---
id: T-0218
title: Add accessible toggles volume sliders and navigation tabs
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: med
ui: med
status: review
depends_on: [T-0217]
touch:
  - game/ui/components/Toggle.gd*
  - game/ui/components/Toggle.tscn
  - game/ui/components/Slider.gd*
  - game/ui/components/Slider.tscn
  - game/ui/components/NavTab.gd*
  - game/ui/components/NavTab.tscn
  - game/ui/gallery/settings_controls.gd*
  - game/ui/gallery/settings_controls.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/ui.csv
  - game/locale/gallery.csv
  - game/tests/integration/test_toggle_slider_tab.gd*
  - docs/qa/T-0218-setting-controls.md
  - tasks/T-0218-setting-controls.md
revision: 1
---

## Goal
Provide native accessible boolean/volume controls and reusable navigation items without settings,
audio or unlock-service wiring. Sound slider sends preview intent only after a changed gesture ends.

## Context
DESIGN.md#toggle, #slider-addition, #navtab and reduced-motion mapping. PRIMARY/SURFACE_ALT,
Touch.MIN_TARGET, check in on knob; native Slider thumb hit area >=144 and step.1.

## Current state
Fresh main e191b21 contains merged T-0217,358GUT; ActionButton/CatalogAction, Badge,
CatalogSurface and LocaleCatalog available. No final Toggle/Slider/NavTab. Native Godot Slider class
already exists, so catalog class_name is CatalogSlider (file Slider.gd). Owner serial handoff authorized.

## Specification
1. Toggle extends ActionButton, native toggle_mode, value:bool alias to button_pressed; program value
   changes are silent. configure(value:bool,a11y_label_key:String)->Error rejects blank key atomically.
   Public a11y_label_key retains previous valid key on blank assignment. Native toggled emits
   value_changed(bool); mouse/keyboard/focus/shortcut use native Button paths. Unconfigured controls
   suppress own interaction/shortcut without consuming siblings. Disabled states suppress intent.
2. Token track and knob show on check glyph as noncolour cue; off moves knob to opposite side.
   Minimum2x144 track by144 hit area. PRIMARY/SURFACE_ALT, SURFACE knob; visible focus ring.
   Native press/highlight motion inherited; reduction removes movement and preserves state.
   Own translations/name/on-off description survive independent locale/theme/exit/re-entry.
3. CatalogSlider extends HSlider: native range0..1, step.1. configure(value:float,label_key:String,
   sound_preview:bool=false)->Error rejects NaN/Inf/empty key atomically; finite input clamps through
   native range. Unconfigured editable state suppressed and restored when configured; explicit native
   editable=false stays authoritative. Translated name/tooltip and Numeric percentage description.
4. Native theme styles use PRIMARY/SURFACE_ALT; grabber texture144x144 defines at least144 hit area;
   root height>=144. Native value_changed signal handles change intent. preview_requested(float) only
   for sound_preview on changed mouse/touch drag end or changed keyboard directional release;
   program changes and music sliders never request preview. Direct touch is routed explicitly through native range values without event allocations; ignore
   secondary fingers/emulated duplicates. Release without change, cancel/focus
   loss/disable/exit/reconfigure clears gesture, never produces stale request. set_available(bool) atomically cancels even same-frame availability
   changes; direct native editable writes are observed at next input/frame. No Audio/Events SDK call.
5. NavTab extends CatalogAction: configure(icon:Texture2D,label_key:String,locked_label_key="")->Error
   validates glyph/nonempty label atomically; inherited title alias label_key. selected:bool is
   caller-owned state (pressed only emits intent), locked:bool=false, implemented:bool=true.
   Selected has PRIMARY surface plus check cue; locked uses lock icon and supplied level label,
   suppresses native focus/mouse/shortcut; inherited highlighted adds NEW Badge and static ring.
   Unbuilt implemented=false hides item and suppresses own input. Re-entry/locale/theme/resize safe.
6. SettingsControls gallery scrolls Toggle off/on/pressed/disabled, sliders0/.5/1 and disabled plus
   sound/music, NavTab normal/selected/locked/highlighted and hidden unbuilt. Demonstrate native
   interaction, translated labels and large-text growth. No feature screen/service/config/save wiring.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1/2 dedicated catalog components; R-UI-3 token/theme visuals/motion; R-UI-4 static locale copy;
R-UI-5 generated themes untouched; R-UI-6 native3classes xPL/PSEUDO xdefault100/HC130 matrix.
Physical device/screen-reader/taste/Opus gates stay open.

## Tests
- Toggle native pointer/key/shortcut value intent, program silence, invalid configuration atomic,
  required accessible key, off/on check cue/focus/disabled, reduction and locale/theme/re-entry.
- Slider finite clamp/step/invalid atomic/required name,144 thumb+root/native pointer/keyboard value,
  release-only changed sound preview, program/music/no-change/cancel/disable/reconfigure/exit/re-entry.
- NavTab native intent/caller selected state, selected check, lock/level label, highlightedNEW,
  hidden/unconfigured/locked shortcut suppression preserving siblings, locale/theme/wrapping/re-entry.
- Gallery inventory/scroll and all controls fitHC130/PSEUDO; existing assertions retained, full
  make check, scope/task lint, independent fresh review and13 final-headCI controls before serial merge.

## Out of scope
Settings/audio/feature unlock business rules, physical-device certification, new tokens/themes,
project/export/platform/service/save/config/ROADMAP edits.
