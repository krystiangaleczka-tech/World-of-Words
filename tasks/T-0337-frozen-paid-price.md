---
id: T-0337
title: Keep issued Economy prices stable after an atomic write attempt
epic: E20
type: contract
area: services.save
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0336]
touch:
  - game/services/save.gd
  - game/services/save/atomic_save.gd
  - game/services/economy.gd
  - game/tests/integration/test_paid_tool_transactions.gd
  - docs/contracts/paid-tools.md
  - tasks/T-0337-frozen-paid-price.md
revision: 1
---

## Goal
Finish T-0278's retry boundary: remote price changes cannot strand an already issued
paid request after its first storage failure. Chris's request includes this prerequisite.

## Current state
Main 6de4346 contains the paid request protocol. Economy.validates_prepared compares
current reward/price values and journal limit on every retry. AtomicSave retains the
exact issued candidate after _started, so a later price override would reject the
old candidate forever while the Save lease prevents new work.

## Specification
Expose read-only Save.transaction_started(transaction: SaveTransaction) -> bool,
delegating to AtomicSave.started(transaction). True only for the current validated
lease after the actual write attempt begins. Economy retains registered approval,
Save/transaction/hash/Progress validation and all existing barriers, but compares live
price/reward/journal configuration only before that first attempt. Afterwards use
its already issued immutable payload. Do not regenerate cost, rewards or journal
entries. The original request/full hash and post-candidate equality remain required.

## Tests
Append a real-owner regression to test_paid_tool_transactions.gd: fail the first
write, change the canonical hint price, retry successfully at the old price exactly
once; a subsequent distinct tool uses the new price. Repeat final-cell settlement
including completion reward; pre-write price-change rejection remains tested.

## Acceptance
Full check, scope/task checks, independent fresh review and all CI. No UI activation,
new balance values, schema shape, dependency or autoload change.

## Rollback
Keep committed proofs and disable callers; do not discard resolved paid receipts.
