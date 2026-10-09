---
id: T-0134
title: Select, inspect and complete a level from developer tools
epic: E09
type: feat
area: features.debug
risk: low
executor: sol
think: low
ui: low
status: ready
depends_on: [T-0048, T-0118]
touch:
  - game/features/debug/debug.gd
  - game/locale/debug.csv*
  - game/tests/integration/test_debug_level_tools.gd*
  - tasks/T-0134-debug-level-tools.md
  - tasks/T-0118-level-completion.md
  - tasks/T-0122-pl-annotate.md
revision: 1
---

## Goal
Make the P1 debug screen useful for device QA: select any shipped slot, show its answers, open it or complete it, while retaining the existing confirmed reset.

## Context
- tasks/ROADMAP.md T-0134 and PRODUCT.md FR-DEBUG-01.
- DESIGN.md#rules-quote-these-into-ui-tasks: "A screen task may not create a component"; "No raw numbers in scenes or feature scripts". Use existing TextButton, Label, BoxContainer, ScreenScaffold and Tokens only.
- ARCHITECTURE.md#level-flow: direct service calls; Events for effects only.
- Chris authorized consecutive task execution and merge after independent review and green CI on 2026-10-09. T-0118 and T-0122 merged; their task statuses are recorded as done as metadata bookkeeping only.

## Current state
- game/features/debug/debug.gd extends ScreenScaffold, configures injected Save, Content and Nav; confirmed reset uses Save.debug_reset() and Nav.go_to_level(1).
- Nav.level_slot(), go_to_level(slot), mounted_screen() exist; mounted LevelScreen exposes controller, progress and status_label.
- Content.slot_count(), level_for_slot(slot) return shipped LevelData; word_count()/word(index) expose answers.
- Save.get_section(), set_section(), flush() and language setting exist; progress by_lang states contain current_slot and level_state.
- LevelController.hint() persists before effects and can retry failed durability. is_complete() exposes board completion.
- T-0048 and T-0118 implementations are merged. No slot/answer/completion controls exist in Debug yet.

## Specification
1. In debug builds initialize selection to the mounted slot clamped to shipped content. Previous/Next stay inside 1..slot_count; changing selection performs no save writes or navigation and hides old answers. Disable boundary actions and every level action when content is unavailable.
2. Open uses injected Nav.go_to_level(selected). Show answers toggles a translated label containing only the selected level's declared words; no generated dictionary or bonus mutation. Failed pack load shows a translated retryable error, never stale answers.
3. Complete is an explicit developer progress override: for a selected slot ahead of current progress, set only current_slot and clear level_state for the current language, preserving all other sections and completed history. Flush before navigating; failure stays in Debug with an error and allows retry. Opening a slot alone never performs this override.
4. Mount the selected LevelScreen through injected Nav, then reveal through its existing controller.hint() until complete. Limit attempts to occupied-cell count plus one durability retry, stop on first failure, and leave LevelScreen's existing persistence error retry path available. No economy grants or new events; normal controller effects apply. Completing an earlier replay never moves saved progress backwards.
5. All player-visible debug copy uses debug CSV keys. Labels wrap. Previous/Next share a row with selection. Existing confirmation/reset/Home behavior remains. Disconnect manually connected new signals on exit. Guard callable actions with OS.is_debug_build().
6. Record only merged status bookkeeping for T-0118/T-0122; no other task or ROADMAP edits.

## Tests
File: game/tests/integration/test_debug_level_tools.gd
- test_selection_answers_and_open: clamp/boundaries, selection without writes, declared answers, open through injected Nav, no mutation on open.
- test_complete_selected_and_preserve_other_sections: selected future slot becomes completed durably, Continue layer visible, economy/settings/other language unchanged, earlier replay cannot regress progress.
- test_completion_storage_failure_and_missing_content: failed pre-navigation save stays Debug, explicit retry succeeds, missing content disables actions, failed packs return errors.
- test_locale_and_layout: PL/EN labels refresh and visible controls fit COMPACT with safe insets; confirmed-reset controls retain existing behavior coverage.

## Acceptance
Pinned Godot 4.7.2 make check, task lint, scope, independent fresh review and CI pass. Actual REGULAR/PL runtime screenshot inspected. One task branch and PR; no cheap-executor provenance claimed.
