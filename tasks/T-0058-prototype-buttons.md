---
id: T-0058
title: Add provisional prototype action buttons and gallery
epic: E06
type: feat
area: ui.components
risk: low
executor: sol
think: med
ui: med
status: done
depends_on: [T-0103, T-0107]
touch:
  - game/ui/components/IconButton.gd*
  - game/ui/components/IconButton.tscn
  - game/ui/components/HintButton.gd*
  - game/ui/components/HintButton.tscn
  - game/ui/gallery/controls.gd*
  - game/ui/gallery/controls.tscn
  - game/tests/integration/test_prototype_buttons.gd*
  - tasks/T-0058-prototype-buttons.md
revision: 1
---

## Goal
Supply the catalog buttons needed by the requested prototype, separately from wheel/screens (R-UI-2).

## Context
DESIGN.md#iconbutton, #hintbutton, #rules-quote-these-into-ui-tasks.
“A new component belongs to a separate ui.components task with a gallery.”

## Current state
Tokens from T-0103, level translations from T-0107 and TextButton are available.

## Specification
IconButton extends Button with exported text_key:String, refreshes translated text and accessible name,
uses Tokens.Touch.MIN_TARGET and token font/palette for all states. Native pressed signal.
HintButton is a named IconButton variant for the P1 free, unlimited hint; no price/count or economy.
Both have catalog .tscn resources. Gallery demonstrates enabled/disabled states and PL/EN labels.
No raw visual literals in scripts/scenes; screen composition only uses these existing catalog controls.

## Tests
File game/tests/integration/test_prototype_buttons.gd:
- test_translation_minimum_target_and_disabled_press
- test_hint_variant_and_gallery

## Acceptance
Pinned Godot make check, task lint, scope and independent review pass. No new dependencies or assets.
This prerequisite is necessary for T-0108/T-0117 and does not release any broader Phase1 scope.
