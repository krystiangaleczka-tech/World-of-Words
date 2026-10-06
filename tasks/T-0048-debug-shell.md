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
status: blocked
depends_on: [T-0045]
touch:
  - game/features/debug/**
  - game/locale/debug.csv
  - game/tests/integration/test_debug_screen.gd*
  - tasks/T-0048-debug-shell.md
revision: 1
---

## Goal
A debug-only screen shows app and content versions and offers reset save. It is reachable through
Nav in debug builds; release artifact exclusion is verified by export tasks T-0137/T-0138.

## Context
- `docs/PRODUCT.md#fr-debug-debug-tools` FR-DEBUG-01 and FR-DEBUG-06.
- `docs/DESIGN.md#rules-quote-these-into-ui-tasks`: "A screen task may not create a component. If a needed component or state is missing, STOP (S4) and request a separate `ui.components` task."
- "New component = separate task (`area: ui.components`), including its gallery entry."
- "No raw numbers in scenes or feature scripts"; "Strings shown to players use translation keys".
- `docs/DESIGN.md#screenscaffold-and-safe-areas`: "Every screen root is a `ScreenScaffold`."

## Current state
- `Nav.Screen.DEBUG` and canonical `res://features/debug/debug.tscn` path exist; no public debug entry method exists.
- App version is `ProjectSettings.application/config/version`; `Content.content_version() -> int` exists.
- `Save` has load/settings/section/flush APIs but no reset API.
- No `game/ui/tokens.gd`, ScreenScaffold, button component or component gallery exists.

## Specification
The intended screen uses existing ScreenScaffold/text/button components, token styling and locale keys.
It shows both versions, delegates explicit reset to a reviewed Save-owned API, then returns to Level 1.
Debug routing is gated before mounting the scene. Freeze the exact interfaces and touch scopes in a
new revision after prerequisites exist; do not implement against imaginary APIs.

## Out of scope
Inventing UI components inside this screen task; save schema changes; production data deletion;
slot jump/show answers/complete-level controls (T-0134); export changes (T-0137/T-0138).

## Tests
After unblocking, `game/tests/integration/test_debug_screen.gd` must cover debug-only routing,
version display, isolated-save reset and return to Level 1. Release artifact checks stay with export tasks.

## Acceptance
Blocked until separate UI/gallery and Save reset/debug-route contracts are integrated and this task
is revised to name their APIs, dependencies, approved tokens and executable cases.

## Escalation
S1/S3/S4 and R-UI-1: required components, tokens and reset/routing APIs are absent. Existing roadmap
places token bootstrap after Phase 0 (T-0103), so silently taking that work into a Phase 0 screen would
bypass its gate. Options: an explicit Phase 0 bootstrap plan with separate component/gallery and
Save/Nav contract tasks, or a documented developer-tools exception to the UI requirement.
Planning identified the gaps; no UI code, persistent files, contracts or exports were changed.
