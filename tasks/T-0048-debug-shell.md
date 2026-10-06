---
id: T-0048
title: Build the debug-only version and reset screen shell
epic: E04
type: feat
area: features.debug
risk: low
executor: cheap
think: low
ui: low
status: ready
depends_on: [T-0045, T-0054, T-0055, T-0056, T-0057]
touch:
  - game/features/debug/**
  - game/locale/debug.csv
  - game/tests/integration/test_debug_screen.gd*
  - tasks/T-0048-debug-shell.md
revision: 2
---

## Goal
A debug-only screen shows app/content versions and offers an explicit confirmed reset followed by Level 1.

## Context
- `docs/PRODUCT.md#fr-debug-debug-tools`: FR-DEBUG-01/06; physical release exclusion is T-0137/T-0138.
- `docs/DESIGN.md#rules-quote-these-into-ui-tasks`: "A screen task may not create a component."
- "No raw numbers in scenes or feature scripts"; "Strings shown to players use translation keys".
- `docs/DESIGN.md#screenscaffold`: screen root is the existing ScreenScaffold.

## Current state
T-0054 tokens, T-0055 components, T-0056 Save.debug_reset and T-0057 Nav.go_debug are prerequisites.
They are explicitly planned Phase 0 bootstrap; no phase exit or full T-0103 completion is claimed.

## Specification
Create debug.tscn rooted in ScreenScaffold with a VBox body using existing TextButton scenes and Label
primitives only. App version comes from ProjectSettings, content version from Content.content_version.
Expose configure(save: SAVE_SCRIPT, content: CONTENT_SCRIPT, nav: NAV_SCRIPT) before entering tree
for isolated tests; constants preload the three service scripts. Nav supplies its configured services
before mounting DEBUG; direct gallery instantiation defaults to autoloads.
All text uses translation keys from locale/debug.csv (PL and EN); register this CSV's translations locally
without project.godot changes, refresh on translation notification. Use Tokens for typography/margins.
Buttons: reset request, confirm reset (hidden initially), cancel confirmation, Home. Reset requires an
explicit second press, delegates to Save.debug_reset, and only then calls Nav.go_to_level(1). Cancel does
nothing. Failures show translated error status and keep screen accessible; no automatic retry/deletion.
Screen exposes request_reset(), cancel_reset(), confirm_reset() -> Error and visible text via scene nodes.
Guard _ready and handlers in release; release never resets/mounts diagnostics. No platform calls.

## Tests
`game/tests/integration/test_debug_screen.gd`: test_debug_route_mounts_versions,
test_confirmed_reset_returns_to_level_one, test_cancel_preserves_save,
test_reset_failure_keeps_debug_and_shows_error, test_polish_and_english_copy.
Use injected services with isolated SaveStorage, never actual autoload reset. Existing Nav and boot tests remain unchanged.

## Acceptance
make check and fresh review pass. F3 opens Debug after boot (including missing-content diagnostics).
Manual gallery/editor inspection available; provisional default font and final release exclusions remain
future tasks. No claim of a release artifact check or Phase 0 exit.

## Execution provenance
Codex execution; not evidence of the cheap-model Phase 0 gate.
