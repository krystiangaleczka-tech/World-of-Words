---
id: T-0336
title: Extend the concrete atomic owners to durable paid board tools
epic: E20
type: contract
area: services.save
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0332, T-0242, T-0277]
touch:
  - game/core/board/paid_tool_plan.gd*
  - game/services/save/atomic_request.gd
  - game/services/save/atomic_save.gd
  - game/services/save/save_schema.gd
  - game/services/progress.gd
  - game/services/progress/atomic_progress_port.gd
  - game/services/economy.gd
  - game/tests/integration/test_paid_tool_transactions.gd*
  - game/tests/fixtures/paid_tools/**
  - docs/contracts/paid-tools.md
  - tasks/T-0336-paid-tool-transactions.md
  - tasks/T-0278-paid-tools.md
  - docs/qa/T-0278-paid-tools-preflight.md
revision: 1
---

## Goal
Supply T-0278's missing durable debit + reveal boundary. Chris requested T-0278;
this prerequisite explicitly authorizes its Save/economy/Progress contract extension.

## Current state
Main 14c0895 contains T-0276, T-0277, T-0263 and T-0274. AtomicRequest.valid and
SaveSchema._valid_proof accept only campaign_complete. AtomicSave requires every
approved candidate to advance the slot. Progress.prepare_completion requires a
completed bound board. Economy.prepare_commands authorizes only completion grants.
AtomicProgressPort already serializes typed owner preparation/recovery.

## Specification
- Add pure PaidToolPlan.after(board, kind) -> BoardState: copied deterministic
  Hint/Reveal, null for invalid/complete boards; historical bonus credits survive.
- Progress.paid_tool_request(board, kind, commands) -> Dictionary registers a
  detached candidate, requiring the actual bound current campaign board, same
  lineage/content/language, persisted before snapshot and unlocked tool.
- Economy.tool_commands(kind, complete=false) -> Array[Dictionary] chooses one
  owned item first, else canonical coin price. Never grants before affordability.
  Completed paid boards append existing completion rewards to the same batch.
- AtomicProgressPort.tool_commands(kind, complete=false) exposes only its bound
  Economy owner's proposal, so callers cannot accidentally pair a different wallet.
- Closed paid_tool request adds tool {kind, before, after}; stable operation ID is
  paid_tool:<language>:<slot>:<kind>:<before snapshot SHA256>. Full request hash
  binds prices, commands, content and candidate. Existing campaign request unchanged.
- Reuse concrete owner approvals, Save lease, storage selection, receipt publication
  and recovery. Partial tools persist only level_state and debit; final tools also
  commit stars, completion, unlocks and rewards. No shared dirty staging shortcut.
- Extend the existing v4 receipt namespace without changing its eleven-field
  shape. Existing v4 saves require no migration. Keep the extended reader for any
  rollback; older builds are not a supported downgrade once new proofs exist.
- Owners revalidate original board, content and config at the final write boundary.
  Nothing publishes on unresolved errors; retries keep exact prepared identity.

## Tests
New integration suite using real owners and file storage: both item and coin costs,
insufficient/locked/complete/stale/foreign board rejection, partial and final tools,
crossings, unchanged live board before success, stable replay and conflicting hash,
all five storage checkpoints with retry and restart, reentrant writes, config/board
replacement rejection, preservation of other sections and historical bonus credits.

## Scope refinement
One cross-owner transaction capability necessarily spans six existing boundary/owner
files plus its small pure selector. Presentation is split into T-0278. No runtime
activation, balance, SDK, dependency, autoload, project or pipeline changes.

## Acceptance
Required make check, scope/task checks, fresh independent review and all CI pass.

## Rollback
Disable callers; retain the extended proof reader and all durable receipts.
