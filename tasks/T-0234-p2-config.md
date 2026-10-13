---
id: T-0234
title: Register documented P2 economy and feature defaults
epic: E15
type: feat
area: data.config
risk: high
executor: sol
think: med
ui: none
status: done
depends_on: [T-0230]
touch:
  - game/data/config/*.json
  - tools/tests/test_check_registries.py
  - game/tests/integration/test_p2_config.gd*
  - tasks/T-0230-economy-contract.md
  - tasks/T-0234-p2-config.md
  - docs/qa/T-0234-p2-config.md
revision: 2
---

## Goal
Ship canonical documented defaults without adding gameplay callers or approving store products.
Owner requested drafting and implementing this missing task alongside T-0233.

## Context
GAME_DESIGN.md config key registry supplies exact defaults, ranges and owners.
PRODUCT.md owns key names. T-0203 owner decisions retain one star regardless of hints,
canonical unlocks and consent order; Q6 small-pack amount is only a starting value.

## Current state
Config.load validates prefix JSON definitions with six fields through ConfigRegistry.
Only hint.json and unlocks.json exist and already match the canonical table.
T-0230 value objects are merged on main but its task status still says review;
reconcile that bookkeeping to done within this task's explicit scope.

## Specification
1. Add economy, bonus, ads, consent, meta, onboarding and iap prefix documents.
   Copy every P2 row of GAME_DESIGN's table for these prefixes with exact defaults/ranges/owners.
   Include economy.reward.daily and unlocks.daily_slot as inactive documented P3 values consumed
   by shared tables; no daily runtime activation. Only iap.coins_s.amount, no P3 packs.
2. Keep all entries remote:false; remote tuning policy remains T-0254. Preserve existing hint and
   unlock entries unchanged. Definitions have default/type/range/description/owner/remote.
3. Config remains explicitly loaded, no API, boot, SDK, Save, product IDs or store pricing changes.

## Tests
New test_p2_config.gd loads shipped config and checks all 26 added defaults and types, canonical
hint/unlocks, consent-before-tools/ads ordering, fixed star default, RewardTable interoperability.
Validate numeric bounds and nonremote metadata for all added entries using ConfigRegistry.
Full make check, task lint and scope check against origin/main.

## Rollback
Revert new unused registry files. No live wallets, purchases or schema change.

## Escalation log
S5: owner authorized changing the shipped-registry test count from 9 to 35 in revision 2.
