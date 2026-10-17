---
id: T-0338
title: Commit bonus-word checkpoints and chest redemption durably
epic: E20
type: contract
area: services.save
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0278, T-0231, T-0242]
touch:
  - game/services/save/atomic_request.gd
  - game/services/save/atomic_save.gd
  - game/services/save/save_schema.gd
  - game/services/progress/transaction_values.gd*
  - game/services/progress.gd
  - game/services/economy.gd
  - game/tests/integration/test_bonus_transactions.gd*
  - docs/contracts/bonus-progress.md
  - tasks/T-0338-bonus-checkpoints.md
revision: 1
---

## Goal
Provide T-0280 a durable bonus counter and completion-only chest settlement. A
word checkpoint and its bonus credit must survive together; replay cannot credit
again or redeem a chest twice.

## Context
GAME_DESIGN.md#bonus-chest: "the chest opens on the next Level complete layer,
never mid-level" and "Surplus words carry over." FR-BONUS-02/03/04.
The existing T-0336/0337 coordinator already owns exact issued candidate retries.

## Current state
Real P2 Save/Progress/Economy and AtomicProgressPort are merged. AtomicRequest has
campaign_complete and paid_tool variants; Save accepts only owner-approved joint
candidates and eleven-field receipts. Progress.save_level currently checkpoints
only its board; Economy's pure ledger supports bonus arithmetic but the service
neither credits bonus words nor redeems chests. T-0280 cannot safely glue these via
a bonus_found side-effect listener or a separate grant.

## Specification
- Add explicit Progress.configure_bonus_progress() -> Error, valid only for ready
  real P2 without pending work. Default P1/P2 legacy checkpoints remain unchanged;
  this enables atomic Progress.save_level for T-0280 before mounting its screen.
- Keep pure checkpoint snapshot/request construction and existing receipt value checks in a small internal
  ProgressTransactionValues helper, preserving the Progress owner below its file-size limit.
- Add Progress.checkpoint_request(board) -> Dictionary for the actual current bound
  incomplete board, current language/content/lineage and exact committed baseline.
  Closed campaign_checkpoint requests contain checkpoint:{before,after}, no economic
  commands or progress delta, and unchanged progression domain. Identity:
  campaign_checkpoint:<language>:<slot>:<SHA256(before)>:<SHA256(after)>.
- Validate the after snapshot via current LevelData, preserve all previously found
  words, bonus credits and revealed cells, reject newly introduced retired bonus
  words. Register exact board identity/snapshot/config and revalidate at final write.
  A no-op checkpoint writes nothing. Retain exact pending request and issued retry;
  reject foreign board, changed candidate, content/language/lineage or extra fields.
- Within that same candidate Economy increments bonus_counter by newly found current
  bonus words only when bonus meter is unlocked (recorded unlock or canonical slot).
  Historical retired credits remain preserved and never credited again. No chest
  redemption mid-level, even when counter exceeds target. No ordinary grant/spend.
- For both ordinary and paid final completion, Economy appends the canonical chest
  coin grant to completion commands, consumes full groups from the persisted counter
  and retains surplus in the SAME approved candidate. All groups redeem once; zero
  configured coin reward still consumes groups. No wallet/counter safe-int overflow.
  Rewards and target are frozen in the issued Economy approval after write starts;
  changed config before the first write rejects. Completion remains item/coin debit
  before rewards, so a reward cannot finance an unaffordable paid tool.
- Read-only Economy.bonus_chest_redeemed(chests:int, coins:int) publishes only for a
  matching issued live completion receipt and original registered approval metadata,
  once under Save's write barrier, including zero coin reward. No historical replay
  invents a new notification after restart; durable grants remain in the receipt.
- Use the existing exact integer MAX_SAFE_COUNT for v4 JSON numeric bounds, converted
  explicitly for float comparison. The old decimal float literal under-accepted the
  top safe integer in the pinned engine; overflow fixtures exposed this one-unit
  boundary issue. No new numeric range or v3 reader change.
- Extend existing receipt namespace reader without changing v4 shape. Never drop
  proofs. Rollback retains this reader; older builds are unsupported downgrades once
  checkpoint receipts exist. No backfill of pre-activation, previously saved bonus
  words whose credit history is unknown. This feature has not been Boot-activated.

## Tests
Real owners/storage: checkpoint and counter commit together; threshold does not pay
mid-level; duplicate/no-op, rejection of forged/backward/foreign intents; unlock,
historical credit preservation; every five filesystem interruption points and fresh
owner restart; completion groups/surplus and zero reward; ordinary/paid final action
retry and once-only effects; frozen target/reward after failed write; overflow fails
without partial mutation; unrelated sections preserved. Existing tests unchanged.

## Acceptance
Pinned full make check, scope and independent fresh Sol review; all15 CI including
both Android jobs green before exact-head squash merge. No UI or Boot activation.

## Rollback
Disable bonus opt-in; keep the expanded reader and all existing receipts. No schema
shape migration or downgrade to readers unaware of campaign_checkpoint proofs.
