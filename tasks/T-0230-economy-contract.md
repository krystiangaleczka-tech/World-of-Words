---
id: T-0230
title: Pure wallet and configured reward contract
epic: E15
type: contract
area: core.economy
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0203]
touch:
  - game/core/economy/wallet_snapshot.gd*
  - game/core/economy/reward_table.gd*
  - game/tests/unit/core/economy/test_wallet_contract.gd*
  - docs/qa/T-0230-economy-contract.md
  - tasks/T-0230-economy-contract.md
revision: 1
---

## Goal
Define tested pure wallet arithmetic and configured reward/price values for T-0231 implementation.

## Current state
Main2f1fd8eb has Save v3 coins/items/global bonus counter; Economy is still a ServiceStub.
No core/economy exists. T-0203 accepted intents are done; canonical keys live in PRODUCT/GAME_DESIGN.

## Specification
1. WalletSnapshot RefCounted: from_dict({coins:int,items:{hint:int,reveal:int}})->WalletSnapshot
   or null; strict closed shape, accept JSON integral floats only at this deserialization boundary,
   canonicalize to int. Values nonnegative and ≤MAX_SAFE_COUNT (2^53−1 for JSON persistence).
   snapshot()->Dictionary is isolated. No service/Node/I/O/global config.
2. valid_amounts(flat {coins?,hint?,reveal?})->bool validates nonnegative int values, known keys,
   at least one positive component, safe count bound. Empty/allzero/fraction/bool/unknown rejected.
   can_afford(amounts)->bool; granted/spent(amounts)->WalletSnapshot or null. Operations atomic,
   immutable source/payload; zero on any component allowed, negative result/overflow rejected.
3. RewardTable.from_config(values:Dictionary)->RewardTable or null reads exact canonical nine
   economy keys: prices hint/reveal; rewards level_complete/double_multiplier/bonus_chest/
   rewarded_hint/rewarded_coins/daily; grant.onboarding_hints. Extra unrelated injected keys ignored.
   Values typed nonnegative safe int; prices/multiplier positive. No hardcoded reward defaults.
   price(tool)->flat coins amounts; reward(source,double_level=false)->flat amounts. Supported
   sources correspond to canonical keys. Double flag only valid for level_complete; overflow
   rejected. Daily value is a future P3 table entry, no runtime daily grants.
4. T-0231 will own a mutable EconomyLedger using these values, reasons and bonus carry-over.
   This task implements value objects/arithmetic as the executable contract; no gameplay changes,
   service grants/journals/events, registry balance changes, SDK or save format changes.

## Tests
Wallet serialization/copy isolation; exact coins/hint/reveal grant/spend, mixed atomic failures,
can_afford boundaries, invalid payloads/types and safe-range overflow. Config-driven nondefault
reward/price outputs, x2 only base completion, unknown/missing/type-invalid config and overflow.
Full make check, task/scope lint, fresh independent exact-head review and13CI before merge.

## Rollback
Pure unreferenced core values can be reverted; no persistence/runtime behavior changed.
