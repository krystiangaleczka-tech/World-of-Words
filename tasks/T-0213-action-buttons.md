---
id: T-0213
title: Finalize PrimaryButton SecondaryButton and TextButton action states
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
  - game/ui/components/ActionButton.gd*
  - game/ui/components/PrimaryButton.gd
  - game/ui/components/SecondaryButton.gd*
  - game/ui/components/SecondaryButton.tscn
  - game/ui/components/TextButton.gd
  - game/ui/tokens.gd
  - game/ui/theme/generate_theme.gd
  - docs/design/tokens.css
  - docs/DESIGN.md
  - game/ui/gallery/actions.gd*
  - game/ui/gallery/actions.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/gallery.csv
  - game/tests/integration/test_action_buttons.gd*
  - game/tests/unit/ui/test_v1_tokens.gd
  - docs/qa/T-0213-action-buttons.md
  - tasks/T-0213-action-buttons.md
revision: 2
---

## Goal
Complete Ceramic catalog action buttons with wrapping copy, loading suppression, theme-aware
states, optional sublabels and explicit ad cues, retaining existing native pressed signals.

## Context
- DESIGN.md#primarybutton, #secondarybutton, #textbutton-addition, #accessibility.
- DESIGN.md#level-motion: button press scale 0.96, FAST/OUT.
- DESIGN.md#rules-quote-these-into-ui-tasks; roadmap T-0213.

## Current state
- Main ab67ff0; pinned reviewed T-0212 b748d1e is the implementation parent. Stack drafts;
  prerequisite merges and human visual/device acceptance remain open.
- PrimaryButton extends provisional IconButton and exposes text_key, text, accessibility_name,
  disabled and native pressed. Level completion tests assert those and native keyboard input.
- TextButton extends Button, exposes text_key, set_busy(bool), underline_segment(); debug callers
  depend on native text/pressed/disabled and the busy method's saved-disabled behavior.
- SecondaryButton and final action gallery do not exist. Godot 4.7.2 Button supports autowrap_mode.
- Generated themes provide Palette colours, Type LABEL/CAPTION sizes/fonts; Lucide video icon exists.

## Specification
1. Shared ActionButton extends native Button; PrimaryButton and TextButton switch to it;
   add SecondaryButton scene/script. Preserve text_key, translated native text/accessibility_name,
   pressed/disabled, TextButton.set_busy and underline_segment. No screen wiring change.
2. Export text_key:String, sublabel_key:String, loading:bool, highlighted:bool. Native icon stays
   caller configurable. All copy translates exactly once; independently register/release LevelCopy.
   Native autowrap grows labels at 130%/PSEUDO, never truncates. Sublabel uses Caption and wraps;
   its measured height reserves separate bottom content space. Min hit height is Touch.MIN_TARGET.
3. Loading saves/restores disabled and icon; repeats are idempotent and native activation is blocked.
   A token-sized spinner replaces the icon and keeps the main label. Reduced motion uses a static
   spinner. Secondary badge=ad retains a separate official video cue even while loading/disabled.
   Unknown badges reject atomically through configure_badge(value:StringName)->Error; empty/ad only.
4. Theme/locale updates and detach/re-entry refresh appearance. Primary has PRIMARY/ON_PRIMARY,
   LOW elevation, pill corners; disabled TEXT_MUTED/SURFACE_ALT. Secondary SURFACE/PRIMARY with
   3px STROKE normal, PRIMARY pressed outline. Text has transparent styles and pressed underline.
   Focus ring is visible, distinct, and does not fill the control. Button fonts use Type.LABEL.
5. Press/release tween scale around centre with FAST/OUT; highlight pulses up to three SLOW cycles.
   Kill previous tween before another; loading/disabled/exit cancel motion and restore scale.
   Reduced motion has no scale movement. Add only Action.PRESS_SCALE=0.96 and OUTLINE_WIDTH=3
   to Tokens and generated CSS mirror; document in DESIGN. Generated theme files unchanged. Extend the existing v1 mirror test
   GROUPS/RATIOS for the two new constants, preserving every existing assertion.
6. Actions gallery: scrollable labelled Primary/Secondary normal/pressed/disabled/loading/highlighted,
   ad and icon/sublabel examples; Text normal/pressed/disabled/busy. Use locale keys and current theme.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1/R-UI-2: catalog component task; screens use catalog components.
- R-UI-3: all visual values use Tokens/current theme. R-UI-4: all copy uses locale keys.
- R-UI-5: regenerate CSS; never hand edit themes. R-UI-6: inspect three classes x PL/PSEUDO,
  default100/HC130 with fake insets. Native local evidence does not close device/taste gates.

## Tests
- Native keyboard/mouse activation once; loading/busy rejects activation and restores initially disabled.
- Translation/sublabel/accessibility and pseudo exactly once; live locale/theme, HC130 font and colours.
- Wrapping at compact width grows labels/sublabel without clipping; icon/ad/spinner fit and ad persists.
- Badge rejection atomic, icon restore, pre-ready properties, detach/re-entry; disabled/highlight cleanup,
  finite pulse and reduced-motion scale; Text pressed underline in local coordinates.
- Gallery all states; preserve existing expectations; extend only the mirror enumeration; make check, scope/task lint and fresh
  independent review, final-head CI. Capture local native gallery matrix and existing game smoke.

## Out of scope
Production screens, final IconButton/Badge T-0214, new dependencies/autoloads, gameplay, save,
monetization, platform/project/export/signing settings and ROADMAP changes.

## Escalation log
2026-10-12: owner requests further World of Words tasks. Prepare missing bounded T-0213 from
roadmap on reviewed T-0212; explicitly specify shared action API, compatibility-preserving
inheritance changes and two canonical visual tokens. Prior human/device/Opus gates remain open.

Revision 2: existing mirror completeness test explicitly enumerates groups; add Action/PRESS_SCALE
to that enumeration to test the new canonical constants instead of weakening completeness.
