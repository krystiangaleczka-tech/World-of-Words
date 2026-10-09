---
id: T-0118
title: Continue from durable level completion without a loading screen
epic: E07
type: feat
area: level.flow
risk: medium
executor: sol
think: med
ui: med
status: review
depends_on: [T-0117, T-0112, T-0114]
touch:
  - game/features/level/level.gd
  - game/services/nav.gd
  - game/ui/components/PrimaryButton.gd*
  - game/ui/components/PrimaryButton.tscn
  - game/locale/level.csv*
  - game/tests/integration/test_level_completion.gd*
  - tasks/T-0118-level-completion.md
revision: 1
---

## Goal
Show a minimal P1 completion layer after persistence succeeds and let the player continue to the already preloaded next level.

## Context
- tasks/ROADMAP.md T-0118, FR-BOARD-07, FR-PROG-02, NFR-03.
- docs/DESIGN.md#level-p1-provisional and #flow-level-complete: translated title and one plain PrimaryButton Continue.
- docs/ARCHITECTURE.md#level-flow: direct service calls, Events only for effects.
- docs/DESIGN.md#rules-quote-these-into-ui-tasks: "No raw numbers in scenes or feature scripts"; "A screen task may not create a component."

## Current state
LevelScreen composes BoardView, LetterWheelView, WordPreview, IconButton and HintButton; LevelController.completed fires only after successful progress persistence. Content.level_for_slot caches packs. Nav.go_to_level mounts configured scenes. PrimaryButton is specified in the catalog but does not exist.

## Specification
First add the plain P1 PrimaryButton in its explicitly listed component scope, as a reusable catalog component derived from IconButton with PRIMARY/ON_PRIMARY token styling, disabled/focus states and translated text_key. It uses native pressed and disabled semantics; no P2 spinner or highlight behavior. Then compose it on LevelScreen. Chris explicitly approved this component exception in the implementation session on 2026-10-09.

Expose configure_navigation(nav: Node) before mounting; Nav injects itself. On durable completion preload Content.level_for_slot(slot+1), show translated title plus Continue, disable gameplay HUD and leave the completed board visible. Continue disables itself immediately, routes once to the next slot through injected Nav and never writes progress again. A navigation failure restores the button with a translated error and allows retry. If the next content pack failed, preloading can be retried by Continue; never skip a slot. No loading screen.

A final shipped slot has a terminal translated title and disabled Continue. On boot with progress.current_slot() greater than Content.slot_count(), the clamped final slot renders as completed using all level-word cells, without saving, replaying effects or allowing gameplay. Debug replay of an earlier slot remains playable. Locale updates title/actions/error. No rewards, ads, consent or Home unlock wiring in P1.

## UX
Existing composition: ScreenScaffold, Label, BoxContainer, BoardView, PrimaryButton created in the approved component scope. All visual spacing/colors/type/motion use Tokens; text translation keys. Completion row above gameplay, button and title remain within safe margins at COMPACT, REGULAR, TABLET and PL/PSEUDO. Actual runtime screenshots required; geometry does not prove device feel.

## Tests
- test_primary_button_catalog_states: translated accessible text, primary/disabled token styles and native action.
- test_completion_preloads_and_continue_routes_once: no layer before completion; persisted completion precedes visibility, next board mounts on Continue, duplicate old-button activation cannot advance again.
- test_failed_persistence_and_navigation_retry: failed completion hides layer, action retry commits once; unavailable navigation has translated retryable error without extra writes.
- test_terminal_content_resume_and_locale: last-slot finish and saved beyond-end boot show terminal disabled state; locale refresh and no writes/effects on boot.
- test_completion_layout: safe-area geometry in the three classes and expanded strings.

## Acceptance
Pinned Godot 4.7.2 make check, task lint, scope and independent review pass. One task/branch/PR; actual Codex provenance recorded.

## Escalation log
S4: PrimaryButton is missing and AGENTS disallows creating a component in a screen task. Proposed explicit component scope plus tests is prepared above; Chris approved the explicit component scope and execution on 2026-10-09.
