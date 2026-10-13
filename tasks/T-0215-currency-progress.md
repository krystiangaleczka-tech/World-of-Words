---
id: T-0215
title: Add animated currency pills and accessible linear progress
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0214]
touch:
  - game/ui/tokens.gd
  - docs/DESIGN.md
  - docs/design/tokens.css
  - game/ui/components/CurrencyPill.gd*
  - game/ui/components/CurrencyPill.tscn
  - game/ui/components/ProgressBar.gd*
  - game/ui/components/ProgressBar.tscn
  - game/ui/gallery/currency.gd*
  - game/ui/gallery/currency.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/ui.csv
  - game/locale/gallery.csv
  - game/tests/integration/test_currency_progress.gd*
  - docs/qa/T-0215-currency-progress.md
  - tasks/T-0215-currency-progress.md
revision: 2
---

## Goal
Display balances with tabular numeric count-up and optional native action, and progress with a
visible completion icon/label. Components present caller data; no economy or persistence calls.

## Context
- DESIGN.md#currencypill, #progressbar, #level-motion, #accessibility.
- Count-up is capped by Motion.COUNT_UP_MAX; fill uses BASE/OUT. Reduced motion settles immediately.

## Current state
- Fresh main70ce77b includes merged T-0214 and all reviewed predecessors. Owner explicitly authorizes
  merging and five further serial tasks; legacy parent metadata keeps manual device gates open.
- ActionButton provides native input, themes, reduced-motion and protected lifecycle/layout hooks.
- Numeric font, Palette/Elevation, official coins/star/check icons and gallery switches exist.
- No CurrencyPill or catalog ProgressBar exists (Godot's native ProgressBar name remains reserved).

## Specification
1. CurrencyPill extends IconButton (shared native ActionButton lifecycle and existing TopBar slot compatibility). Export kind:coins|stars, value:int>=0, action_enabled:bool=false;
   expose displayed_value:int and counting:bool. set_value(v:int,animate:bool=true)->void clamps negative
   values to0; finite count tween ends at exact target (also large int targets). Interrupted updates
   start from current displayed value. Kind invalid assignments preserve previous kind.
2. Tabular Type.NUMERIC, official icon, SURFACE pill/MID elevation; retain target>=Touch.MIN_TARGET.
   Passive balance is visually readable but native activation/focus disabled. Enabled native pressed
   emits action_requested(kind:StringName) once. Raw ui.currency.* accessibility keys plus numeric
   description translate once. No action if loading or availability disabled.
3. Count uses min(SLOW+COUNT_UP_STEP*abs(delta),COUNT_UP_MAX)/OUT, then one FAST/SPRING pop; previous count/pop killed before replacement.
   Reduced motion before/during count settles exact target without pop. Exit settles/releases signals
   and translations; re-entry safe. No process allocations or service calls.
4. CatalogProgressBar extends VBoxContainer, value:float0..1, tint:primary|bonus, label_key:String;
   set_value(v:float,animate:bool=true)->Error rejects NaN/Inf atomically and clamps finite out-of-range.
   Expose displayed_value and filling. Native ProgressBar child shows token track/fill, no percentage.
   Completion shows official check and translated ui.progress.complete even without label_key.
   Optional label wraps; passive input/no focus. Only displayed completion shows complete cue.
5. BASE/OUT fill starts from displayed state, cancels previous tween. Reduction/exit settles target;
   locale/theme/re-entry safe with independently owned translations. No generated theme edits.
6. Currency gallery covers0/99999, coins/stars, passive/actionable, counting/highlight, progress0/.5/1
   and both tints, plus replay actions for native movement. Use existing shell review switches.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1/2: dedicated catalog components, no production screen wiring.
- R-UI-3: all visuals/motion use Tokens/current theme. R-UI-4: static copy uses locale keys.
- R-UI-5: generated theme untouched. R-UI-6: native gallery3 classes xPL/PSEUDO xdefault100/HC130;
  physical device and phase/taste gates remain open.

## Tests
- Coin/star glyph/font/tabular/target/HC and native actionable/passive input; copy/pseudo once.
- Negative/large exact targets, interrupted count, completion pop, reduced before/during and exit/re-entry.
- Progress clamp/NaN/Inf atomicity, both theme tints, displayed fill/interruption/completion cues,
  optional wrapping copy/locale ownership and reduction/exit/re-entry.
- Gallery states; existing assertions unchanged; make check, scope/task lint, fresh independent review,
  native12-preview matrix/startup smoke and final-head CI before serial merge.

## Out of scope
Economy/config/save, production screen wiring, ads/IAP/platform/accessibility certification,
new dependencies/themes and ROADMAP edits.

## Escalation log
Owner's explicit merge+five-task instruction authorizes this bounded wave on merged technical
parents; retained review metadata/manual acceptance does not block this technical serial handoff.

Revision2: transcribe DESIGN's existing20ms count cadence into Motion.COUNT_UP_STEP and generated
CSS, document the existing formula; no economy value changes. Availability changes during loading
update its restoration state, and native input reasserts passive suppression.
