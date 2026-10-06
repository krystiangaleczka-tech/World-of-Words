---
id: T-0055
title: Add provisional ScreenScaffold and TextButton with a gallery
epic: E04
type: contract
area: ui.components
risk: high
executor: sol
think: med
ui: low
status: done
depends_on: [T-0054]
touch:
  - Makefile
  - game/tests/unit/ui/test_tokens.gd
  - tools/tests/test_gut_failure_guard.py
  - game/ui/components/ScreenScaffold.*
  - game/ui/components/TextButton.*
  - game/ui/gallery/debug_components.*
  - game/tests/integration/test_debug_components.gd*
  - tasks/T-0055-debug-components.md
revision: 3
---

## Goal
Provide reusable provisional catalog components for Debug, with no service dependencies.

## Context
- `docs/DESIGN.md#screenscaffold`: every screen uses ScreenScaffold; P1 safe-area-only version.
- `docs/DESIGN.md#textbutton-addition`: low-emphasis text action, minimum Touch.MIN_TARGET height.
- `docs/DESIGN.md#rules-quote-these-into-ui-tasks`: "New component = separate task (`area: ui.components`), including its gallery entry."
- "No raw numbers in scenes or feature scripts"; "Strings shown to players use translation keys".

## Current state
Tokens subset exists after T-0054. No component scenes or gallery exist; built-in Godot font is provisional.

## Specification
ScreenScaffold extends Control; exposes body: VBoxContainer, layout_class: StringName and
layout_class_changed(cls), exported debug_insets: Rect2 (left/top position, right/bottom size).
Its full-rect background uses Palette.BG, body uses Space.M padding plus safe-area insets. Real display
insets scale from window to viewport coordinates; headless uses zero. Recompute on resize. Public
apply_insets(insets: Rect2, viewport_size: Vector2) -> void supports deterministic gallery/tests;
classify usable safe height/width using the two Layout thresholds. Never calls services.
TextButton extends Button; exported text_key: String uses tr(), flat provisional style, token LABEL font,
PRIMARY normal/TEXT_MUTED disabled, min height MIN_TARGET, native pressed/disabled/focus behavior.
Pressed text is underlined. underline_segment() -> PackedVector2Array exposes the two LOCAL drawing
endpoints to gallery geometry checks, independent of the button's parent position. set_busy(busy: bool) suppresses presses while busy, preserving caller-disabled
state; intent is native pressed signal. This provisional component does not claim full P2 theme/a11y.
Add matching .tscn scenes and a gallery scene displaying the scaffold and enabled/disabled/busy buttons.

## Tests
`game/tests/integration/test_debug_components.gd`: test_scaffold_safe_insets_and_layout_classes,
test_button_translation_and_min_target, test_button_busy_preserves_disabled, test_gallery_instantiates, test_pressed_underline_uses_local_coordinates.

## Validation correction
T-0054's purity assertion used an impossible static `Tokens is Node` test. Change the variable's
annotation to Object so both behavioral checks execute. GUT could skip that parse-failed file with
exit 0; Makefile's test target must reject SCRIPT ERROR or failed-script-load output while preserving
normal exit status and expected test-asserted push_error diagnostics. CI already invokes make test.
Add tools/tests/test_gut_failure_guard.py for zero-exit parse/load errors, ordinary asserted errors,
and nonzero native exit. This narrow correction prevents false-green component validation.

## Acceptance
All tests and make check pass. UI impact low: gallery exists for manual inspection; no visual-direction
claim. Default Godot font remains temporary; P2 theme and device review remain future work.

## Rollback
Revert this scoped bootstrap. No persistent schema or release content changes; dependent debug tasks
then require their prerequisites again.
