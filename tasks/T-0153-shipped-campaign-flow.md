---
id: T-0153
title: Exercise shipped campaign play through real navigation and save boundaries
epic: E09
type: test
area: level.flow
risk: low
executor: sol
think: high
ui: none
status: done
depends_on: [T-0151, T-0152]
touch:
  - game/tests/integration/test_shipped_campaign_flow.gd*
  - tasks/T-0153-shipped-campaign-flow.md
revision: 1
---

## Goal
Verify the curated shipped campaign through real Nav, LevelScreen and controller
paths. Detect diagnostic persistence regressions beyond the three fixture levels
without inventing human device or difficulty approval.

## Context
- `docs/ARCHITECTURE.md#level-flow`: the controller orchestrates; Progress persists.
- Astra follow-up `docs/qa/T-0149-audit-followup.md`: automated P1 checks do not
  close device/FUN GATE or create P2 transaction guarantees.
- Owner requested checking recent commits and continuing technical tasks before P2.
- On 2026-10-11 Chris confirmed and approved the reported T-0151/T-0152 Samsung
  S26 Ultra tests. This cloud work does not repeat those device tests.

## Current state
- T-0151's diagnostic tests use three fixture levels and memory-backed SaveStorage.
- T-0119's shipped-content bot tests BoardState directly, not navigation or Save.
- T-0152 ships 65 authored Polish slots at content version 2.
- Nav.configure/start/go_to_level/go_debug/mounted_screen and Debug.open_selected
  support isolated real-screen integration tests; LevelScreen uses seeded shuffle.
- The new integration test file does not exist.

## Specification
1. Load actual shipped content through Nav.start, using isolated injected storage.
   Preserve a partial current-slot board while solving every other shipped slot
   through diagnostics, seeded shuffle, reopen and actual wheel submissions.
2. Required words complete the visible board; at least one existing bonus per
   applicable slot is accepted before completion. Full saved document, live Save
   progress and write count remain unchanged, including application pause.
   Reopen completed diagnostic sessions and verify transient state is discarded.
3. On a shipped current slot, failed persistence suppresses result/completion.
   Explicit retry persists before result publication; completion advances once.
   Continue mounts the next real shipped level without another progress write.
4. Finished-campaign resume retains the completed locked final screen. Earlier
   diagnostic play still works and cannot change the completed campaign save.
5. Tests use public behavior, fixed storage input and existing seeded shuffle;
   no sleeps, new production APIs, generated-content edits or existing-test edits.

## Tests
File: `game/tests/integration/test_shipped_campaign_flow.gd`
- Every non-current shipped slot accepts wheel words/bonus after diagnostic
  navigation and shuffle; completion, pause and reopen leave campaign unchanged.
- Current-slot failure/retry emits only after durable state, advances once and
  continues to the next shipped slot.
- Completed campaign resumes final locked screen and supports isolated early play.

## Acceptance
All new tests and full make check pass. Scope/count/metadata checks and fresh
independent review pass; remote CI is green before squash merge.

## Outcome
Full make check passed with Godot 4.7.2: 247 GUT tests / 13049 assertions,
201 pipeline tests, 142 tools tests and 65 validated shipped levels. All 64
non-current slots were solved through the real wheel after seeded shuffle;
the active slot and completed-campaign path have separate save/retry checks.
Fresh independent review approved 8dfecedc267e130f184d02c6b481fa4a43a10745
without blockers and confirmed the diagnostic assertions fail if T-0151 is
reverted. Scope contains three new files; test count is 397 versus 394 on main.
Final-head remote CI remains required before merge. The approved S26 Ultra
evidence belongs to T-0151/T-0152; this task performed no new device test.
