---
id: T-0239
title: Define pure progress values and configured meta rules
epic: E16
type: contract
area: core.progress
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0203]
touch:
  - game/core/progress/progress_snapshot.gd*
  - game/core/progress/progress_rules.gd*
  - game/tests/unit/core/progress/test_progress_contract.gd*
  - tasks/T-0239-progress-contract.md
  - docs/qa/T-0239-progress-contract.md
revision: 1
---

## Goal
Define immutable pure progress values and injected rules for the mutable T-0240 owner.
Owner requested drafting/executing the missing next two tasks.

## Context
GAME_DESIGN.md stars/postcards/unlocks: one configured star regardless of hints; stars/pieces
never removed; thresholds reveal in order, completion reveals remaining pieces; features unlock
when N becomes current, and once unlocked stay unlocked. No daily star awards.

## Current state
No game/core/progress exists. Progress service persists P1 slots/boards only; no pure P2 meta caller.
Config defines meta.stars.per_level=1, meta.postcard.pieces=4, piece_star_cost=12 and seven unlocks.
Save v3 has per-language stars/location_pieces/postcards/unlocked, but no per-location star ledger.
This contract is domain-only and does not change Save fields or activate retrospective P1 rewards;
T-0241/T-0242 must specify persistence/adaptation and legacy-history disposition before integration.

## Specification
1. ProgressSnapshot RefCounted.from_dict(source)->ProgressSnapshot or null accepts closed shape:
   {current_slot, stars, location_stars:{id:int}, location_pieces:{id:int},
    completed_locations:Array[String], unlocked:Array[String]}. Counts nonnegative safe ints;
   current_slot positive. Integral JSON numbers accepted only at deserialization. IDs nonblank,
   trimmed, unique arrays; unknown/retired IDs preserved. Sum location_stars <= global stars.
   snapshot()->Dictionary deep-copy; default new value is empty progress at slot1. No mutation API.
   Shared static valid_count(value:Variant), valid_id(value:Variant), valid_ids(value:Variant)
   return bool for the rule/ledger boundary; they do not mutate or deserialize state.
2. ProgressRules.from_config(values)->ProgressRules or null: require fixed-one meta.stars.per_level
   (T-0203 Q2), positive safe int meta.postcard.pieces/piece_star_cost and seven unlocks.*_slot.
   Ignore unrelated keys; never read Config globally. Expose stars_per_level and piece_count.
3. revealed_pieces(location_stars,previous,complete=false)->int: max(previous,
   min(configured pieces, integer quotient stars/cost)); completion fills configured pieces.
   Previous credits above a changed cap remain intact; invalid/unconfigured returns -1.
4. unlocked_features(current_slot,previous:PackedStringArray)->PackedStringArray preserves prior
   valid IDs and adds ordered eligible shuffle/bonus_meter/hint/journey/reveal/double_reward/daily.
   Config changes never remove prior IDs. No daily activation. Invalid input/unconfigured returns[].
5. location_complete(highest_completed,last_slot)->bool and region_unlocked(current_slot,first_slot)
   ->bool implement boundary comparisons for positive safe slot ranges; false when unconfigured or
   invalid. No IO, service/Node, Time/random, economy, Events, save or content edits.
6. T-0240 adds a mutable pure ledger: per-location star accumulation, exactly-once sequential
   completions, location/region results, snapshot reload and durable-owner-controlled candidate use.

## Tests
New test_progress_contract.gd: closed shape/types/JSON canonicalization, safe-range/cross-field
validation, arrays/map isolation and retired IDs; config rejection/fixed-one rule/nondefault thresholds;
exact quotient/cap/completion/no-credit-removal, unlock boundaries/prior IDs/config changes,
location/region boundaries and unconfigured behavior. Full make check, scope/task checks.

## Rollback
Unused pure values only; no persisted progress changes.
