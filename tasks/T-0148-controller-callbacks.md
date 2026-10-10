---
id: T-0148
title: Guard controller mutations and configuration during synchronous callbacks
epic: E10
type: contract
area: level.flow
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0147]
touch:
  - game/features/level/level_controller.gd
  - game/tests/integration/test_controller_reentrancy.gd
  - game/tests/integration/test_controller_reentrancy.gd.uid
  - tasks/T-0148-controller-callbacks.md
revision: 1
---

## Goal
Keep one controller action bound to one board and dependency set through all
synchronous callbacks. This technical follow-up specifies the missing reentry
boundary; it does not replace Astra's required P2 owner/transaction work.

## Context
- docs/qa/T-0142-architecture-preflight.md: Q1/Q4 retain explicit controller and
  domain ownership boundaries before P2 callbacks and durable transactions.
- AGENTS.md: signals communicate upward; Events carries effects only.
No save schema, economy, screen-local Progress lifetime or rendering changes.

## Current state
LevelController.configure(board, progress, event_bus) -> void replaces references
unconditionally. _busy guards _commit and its publications, but BoardState
mutation callbacks and INVALID/ALREADY_FOUND publication occur before that guard.
Synchronous listeners can replace references or start another action mid-action.

## Specification
1. Explicitly change configure(...) -> bool: true when idle configuration applies,
   false when an action/callback is active. Rejected configuration has no changes
   or deferred work. Existing callers may ignore the return value.
2. Cover the whole mutation/publication window: set the busy guard before evaluate
   or reveal_cell (including BoardState.completed listeners), retain it through
   persistence and every controller/effect callback, including nonmutating results.
3. During that window submit returns null, hint returns false, configure returns
   false; no nested mutation/write, dependency replacement or pending-state loss.
4. Restore idle after success, ignored reveal or I/O error. Pending failed mutation
   still retries exactly once through the existing explicit action policy.
5. No restriction is added to direct external BoardState mutations: owning code
   must still respect board ownership. No global lock or queued actions are added.

## Tests
- INVALID result callback tries submit/hint/configure: no nested writes, board
  changes or misrouted effects; idle configuration/action subsequently works.
- ALREADY_FOUND callback gets the same protection, no duplicate persisted credit.
- Successful completion checks BoardState.completed, state_changed, result_ready,
  completed and effect callbacks; original board/slot/bus retained through action.
- Persistence failure callback rejects reentry/configuration, keeps pending state;
  successful retry publishes completion/effects once, and idle configuration works.
Run full make check, scope, test count, metadata lint and fresh independent review.

## Acceptance
Tests exercise public methods from actual synchronous signal callbacks. Existing
controller/scene contracts and free P1 retry behavior remain unchanged.

## Rollback
Revert implementation and tests together; previous callback hazard returns.
Existing callers that ignored configure's return remain source-compatible.

## Outcome
Full make check passed: 240 GUT tests / 8868 assertions, 199 pipeline and
142 tools tests. Fresh independent review with no author-history context approved
80645fba56be841676957f1cf93c78e5dfc1d8ee with no blockers. Scope: four files.
Existing controller/scene tests remain unchanged. CI required before merge.
P1 dirty retry policy and screen-local owner lifetime are not changed.
