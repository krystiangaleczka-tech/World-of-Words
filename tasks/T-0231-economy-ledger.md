---
id: T-0231
title: Implement pure reasoned economy ledger and bonus carry-over
epic: E15
type: feat
area: core.economy
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0230]
touch:
  - game/core/economy/economy_ledger.gd*
  - game/tests/unit/core/economy/test_economy_ledger.gd*
  - docs/qa/T-0231-economy-ledger.md
  - tasks/T-0231-economy-ledger.md
revision: 1
---

## Goal
Implement the mutable pure owner of wallet arithmetic and bonus chest carry-over for future services.

## Current state
Main8e5176f has technically merged WalletSnapshot and RewardTable contract/test values from T-0230,
Save v3 from T-0229; Economy service remains ServiceStub. No ledger or runtime reward caller exists.

## Specification
1. EconomyLedger RefCounted from_dict(economy,config)->EconomyLedger or null: deserialize wallet/
   bonus_counter and inject RewardTable plus positive int bonus.chest.words_required. Validate all
   values atomically, accept integral JSON numbers at save boundary, safe-count bound. Snapshot
   contains coins/items/bonus_counter only; journal and owner extensions stay with Economy service.
   Unknown inventory items reject rather than silently drop. No service/Node/Time/I/O or globals.
2. can_afford(amounts)->bool, grant(source:StringName,amounts)->Error, spend(sink:StringName,amounts)
   ->bool use WalletSnapshot, require nonempty trimmed reason, reject invalid/insufficient/overflow
   atomically. Unconfigured ledger returns empty snapshot, false or ERR_UNCONFIGURED as applicable.
3. price(tool)->Dictionary delegates injected prices; grant_reward(source,double_level=false)->Error
   uses configured source amounts, rejects unknown/misapplied double/overflow. A configured zero
   reward is an accepted no-op. No fixed balances, daily runtime activation, journal or event effects.
4. add_bonus(words:int,enabled:bool=true)->Error: positive safe count, no-op before unlock, increment
   global counter only; never grant mid-level. Caller passes only new eligible BONUS credits from
   BoardState; identity dedup/gating/transaction durability remain future service/level tasks.
5. redeem_bonus_chests()->Dictionary explicitly settles all pending whole chests at the future level
   complete boundary. Return {chests:int,reward:{coins:int}}; zero chests returns empty reward.
   Payout uses economy.reward.bonus_chest; exact integer quotient/remainder, surplus carried over.
   Multiplication and wallet overflow reject with {} before mutating counter/wallet. Repeated settle
   without new credits cannot pay again. Configured zero chest payout still consumes whole chests.
6. Wallet and config inputs/snapshots isolated. Roundtrip carry-over works across levels/sessions;
   service T-0232/T-0233 will journal/persist and own durable exactly-once operations. This core
   does not independently certify kill/retry/transaction durability or change the running game.

## Tests
Factory/JSON/config rejection and isolation; reasoned grant/spend atomicity and invalid requests;
injected rewards/price and level multiplier; before-unlock/no-midlevel payout, multi-chest remainder,
repeat settlement and reload; zero configured rewards; large exact division, counter/multiplication/
wallet overflow leaving credit intact. Full make check/fresh exact-head reviewer/checklist/13CI.

## Rollback
Pure core is not used by runtime yet; revert without modifying Save v3 or any wallet balance.
