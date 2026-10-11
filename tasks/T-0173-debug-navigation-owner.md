---
id: T-0173
title: Route level debug through injected navigation
epic: E08
type: fix
area: level.flow
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0172]
touch:
  - game/features/level/level.gd
  - game/tests/integration/test_debug_navigation_owner.gd
  - game/tests/integration/test_debug_navigation_owner.gd.uid
  - tasks/T-0173-debug-navigation-owner.md
revision: 2
---

## Goal
Route level debug through injected navigation. Owner requested another five pre-P2 technical tasks.

## Context
AGENTS.md requires owned signal cleanup and injected services; T-0165 diagnostics exclude background observations. Original Astra P2 ownership requirements and human gates remain separate.

## Current state
LevelScreen.configure_navigation(nav: Node) sets _navigation; debug_button IconButton.pressed connects _on_debug which calls global Nav. _on_continue already uses _navigation.

## Specification
Implement T-0170 Debug button section, add _navigation_supplied: bool=false; configure_navigation stores nav and sets this flag from is_instance_valid(nav). In _on_debug choose _navigation if supplied, otherwise Nav; then debug-build/validity/has_method guard. A destroyed supplied owner must never fall back globally (freed Node==null). Changes limited to that field, configure_navigation and _on_debug. No API or geometry/copy/continue changes.

## Tests
Real LevelScreen/in-memory Save/Contentfixture with two injected Node owners: button signal calls only current owner once; owner destruction and owner lacking go_debug cause no errors/global reroute; unconfigured/null fallback uses Nav under guarded isolated test, restore global routing config; existing screen tests remain unchanged.

## Acceptance
All specified behavior/tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/phase approval inferred.

## UX rules
Existing IconButton only; unchanged labels, tokens, states and geometry.
DESIGN.md#rules-quote-these-into-ui-tasks:
- R-UI-1: A screen task may not create a component.
- R-UI-3: No raw numbers in scenes or feature scripts; use Tokens.
- R-UI-4: Strings shown to players use translation keys.
No visible design change or new components.
