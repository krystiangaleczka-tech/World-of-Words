---
id: T-0054
title: Bootstrap provisional tokens for the Phase 0 debug prerequisites
epic: E04
type: contract
area: ui.tokens
risk: low
executor: sol
think: med
ui: low
status: done
depends_on: [T-0045]
touch:
  - game/ui/tokens.gd*
  - game/tests/unit/ui/test_tokens.gd*
  - tasks/T-0055-debug-components.md
  - tasks/T-0056-debug-save-reset.md
  - tasks/T-0057-debug-navigation.md
  - tasks/T-0048-debug-shell.md
  - tasks/epics/E04-workflow-dry-run.md
  - docs/qa/E04-debug-bootstrap.md
  - tasks/T-0054-debug-tokens.md
revision: 1
---

## Goal
Resolve the missing-token prerequisite with a small subset of the existing provisional DESIGN values.
Freeze the five-task continuation Chris requested: T-0054, T-0055, T-0056, T-0057, then T-0048.

## Context
- `docs/DESIGN.md#tokens`: values are provisional; this work chooses no new visual direction.
- `docs/DESIGN.md#rules-quote-these-into-ui-tasks`: components are separate tasks with gallery entries.
- Chris requests five more tasks after the documented T-0048 block. This explicitly planned bootstrap
  unblocks debug diagnostics before Phase 0 exit without declaring that exit or releasing Phase 1.

## Current state
Tokens, component/gallery and Save reset/Nav debug APIs are absent. Nav and Save v1 are integrated.

## Specification
Create class_name Tokens extending RefCounted with typed nested constants drawn exactly from DESIGN:
Palette BG/PRIMARY/TEXT/TEXT_MUTED/ERROR, Type TITLE/BODY/LABEL/CAPTION, Space S/M,
Touch MIN_TARGET, Layout TABLET_MAX_ASPECT/COMPACT_MAX_ASPECT. No global mutable state or autoload.
Create the three prerequisite task files and revise T-0048 with exact APIs/scopes/tests. Keep it blocked
until all prerequisites are done. Record the minimal bootstrap and deferred full T-0103 token contract.

## Tests
`game/tests/unit/ui/test_tokens.gd`: test_design_values_match (all constants); test_tokens_are_pure.

## Acceptance
Metadata/scope and make check pass. No generated theme, font dependency, save format or gate changes.
