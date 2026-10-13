---
id: T-0214
title: Finalize accessible icon actions and add count and state badges
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0132, T-0203]
touch:
  - game/ui/components/IconButton.gd
  - game/ui/components/Badge.gd*
  - game/ui/components/Badge.tscn
  - game/ui/gallery/icons.gd*
  - game/ui/gallery/icons.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/gallery.csv
  - game/locale/ui.csv*
  - game/tests/integration/test_icon_button_badge.gd*
  - docs/qa/T-0214-icon-button-badge.md
  - tasks/T-0214-icon-button-badge.md
revision: 2
---

## Goal
Provide final native icon actions with required accessible copy, and passive count/lock/new
badges. Reuse the reviewed action-state lifecycle and official Ceramic Lucide textures.

## Context
- DESIGN.md#iconbutton, #badge, #accessibility; PRODUCT.md FR-A11Y-04.
- DESIGN.md#level-motion: native press feedback uses Action.PRESS_SCALE and FAST/OUT.
- Roadmap T-0214, pinned icon assets T-0209 and reviewed action parent T-0213.

## Current state
- Pinned reviewed T-0213 d85cefe is implementation parent; PR139 stacked draft on T-0212.
  Prior prerequisite/device/taste/Opus gates remain open. Scheduling dependency T-0203 is done.
- IconButton extends Button with provisional text_key/translated text and native pressed/disabled.
  HintButton extends IconButton and existing game/gallery callers still use labelled P1 actions.
  Existing prototype tests assert those public values, min target, margins and focus/pressed colours.
- ActionButton provides translated text/accessibility, native activation, theme refresh, bounded
  highlight/press motion and reduced-motion cleanup. It has overridable _kind/_refresh_theme/_refresh_copy.
- Official settings/shuffle/lock textures and generated Caption/Palette/Type resources exist.
  Badge and final icon/badge gallery do not exist.

## Specification
1. IconButton extends ActionButton, retaining existing P1 text_key/native text/accessibility/pressed
   and HintButton behavior unchanged when no final icon is configured. This compatibility mode
   remains until screen/HintButton migration tasks; no screen rewiring here.
2. Export a11y_label_key:String and icon_size:StringName (S|M; M default). Add atomic
   configure_icon(glyph:Texture2D,key:String,preset:StringName=&"M")->Error: reject null glyph,
   empty/whitespace key or unknown preset before modifying any property. Valid configuration
   displays glyph only and translated accessible name/tooltip; key independent from text_key.
   Direct exported empty-key configuration must reject unsafe glyph display by clearing the
   glyph during ready/copy refresh, leaving the labelled compatibility action available.
   a11y_label_key cannot be cleared while a final icon remains configured. Configure final glyphs
   through configure_icon; native icon property remains compatible. Locale applies exactly once.
3. Both sizes retain Touch.MIN_TARGET square hit region; S glyph Space.L, M glyph Space.XL,
   centered native texture. Current theme SURFACE/PRIMARY normal, PRIMARY/ON_PRIMARY pressed,
   SURFACE_ALT/TEXT_MUTED disabled; visible PRIMARY focus ring and bounded highlighted ring/pulse.
   Preserve old content margins and theme font size expectations. Shared motion/loading lifecycle
   disconnects/releases on exit and handles live reduction. No custom glyphs/dependency.
4. Badge extends PanelContainer, passive mouse-ignore and no keyboard focus. Export text:String,
   text_key:String, kind:StringName (info|lock|new); configure(value:String,variant:StringName)->Error
   rejects unknown variants atomically. info displays caller-supplied dynamic count/text (or translated
   text_key); lock shows official lock plus optional count/text; new defaults to translated ui.badge.new.
   Exported invalid kind preserves previous variant. Caption wraps/grows at130%/pseudo, pill radius,
   token padding; info/lock PRIMARY/ON_PRIMARY, new BONUS/ON_PRIMARY. Lock name uses ui.badge.locked;
   accessible name identifies state; optional count uses native accessibility_description. Owned LocaleCatalog translations release
   independently and restore on re-entry. No red marketing state or interactive badge.
5. Scrollable Icons gallery includes both icon sizes x normal/pressed/disabled/highlighted, translated
   state captions, count0/99999, lock and new badges. Use official glyphs and existing shell switches.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1/R-UI-2: dedicated catalog components/gallery, no screen-created widgets.
- R-UI-3: all sizes/colours/motion use Tokens/current themes. R-UI-4: locale keys for static copy.
- R-UI-5: generated themes untouched. R-UI-6: inspect three classes xPL/PSEUDO xdefault100/HC130
  with fake insets; native local captures do not close device/taste/Opus gates.

## Tests
- Atomic null/empty/whitespace/unknown-size configure rejection, safe direct-export rejection,
  labelled compatibility and valid icon-only/native accessible name/tooltip, PL/EN/pseudo exactly once.
- S/M target/glyph geometry, default/HC130 style/focus/disabled, native keyboard/mouse activation once,
  disabled suppression; inherited finite/reduced-motion behavior and re-entry translation ownership.
- Badge info0/99999, lock official glyph/state name+count description, localized new, invalid configuration/kind,
  live theme/locale, caption wrapping130%/pseudo, passive input, independent ownership and re-entry.
- Gallery all states/sizes, existing tests unchanged; make check/task lint/scope, independent review,
  native gallery matrix/startup smoke and final-head CI.

## Out of scope
Production icon screen wiring, HintButton finalT-0219, platform screen-reader certification,
notifications/marketing, new tokens/dependencies, generated themes, project/export/settings,
save/economy/content/signing and ROADMAP changes.

## Escalation log
2026-10-12: owner's further-task instruction authorizes bounded next catalog task and additive API
on reviewed pinned parents. Missing task prepared from roadmap; P1 compatibility mode explicitly
preserved and labelled. Human device/taste/Opus acceptance remains open; do not claim completion.

Revision2: pinned Godot native accessibility getters translate raw property keys even when
auto_translate_mode is disabled. Keep raw keys in those fields to prevent double pseudolocalization;
lock state and optional count use separate name/description fields. CSV importer metadata declared.
