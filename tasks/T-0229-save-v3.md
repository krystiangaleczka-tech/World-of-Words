---
id: T-0229
title: Save schema v3 and lossless v2 migration
epic: E15
type: contract
area: services.save
risk: high
executor: sol
think: xhigh
ui: none
status: done
depends_on: [T-0203]
touch:
  - game/services/save/save_schema.gd
  - game/services/save/save_migrations.gd
  - game/services/save/migrate_v2_to_v3.gd*
  - game/services/save.gd
  - game/tests/fixtures/save/v3.json
  - game/tests/integration/test_save_v3.gd*
  - game/tests/integration/test_save_v2.gd
  - game/tests/integration/test_save_temp_recovery.gd
  - game/tests/integration/test_save_v1.gd
  - docs/qa/T-0229-save-v3.md
  - tasks/T-0229-save-v3.md
revision: 2
---

## Goal
Provide the versioned P2 persistence contract without granting runtime rewards or changing owners.

## Context
Roadmap T-0229; PRODUCT FR-SAVE-04/08; ARCHITECTURE Save/ownership; accepted T-0203 intents.

## Current state
Main1ceec0f has SaveSchema.VERSION2, six independent sections, lossless v1→v2 migration,
SaveStorage recovery/atomic writes, independent section copies and legacy per-language progress.
Existing golden v1/v2 files and migration/current-version oracles are present. T-0203 is done.

## Specification
1. VERSION3: preserve legacy fields/extensions; add economy.bonus_counter, meta.coach_marks_seen,
   meta.onboarding_step, per-language postcards/unlocked and monetization.consent_state,
   last_interstitial_time, last_purchase_slot, shop_coins_ads {date:null,count:0}. Existing
   remove_forced_ads and processed_transactions are the entitlement/deduplication contract.
2. MigrateV2ToV3.migrate(source)->Dictionary is pure, validates required v2 shape before adding only
   missing new fields, copies legacy bonus/coach/interstitial/cap values, preserves earned coins,
   items, purchases, language progress, snapshots, extensions and valid already-added fields.
   Reject conflicting legacy/new fields rather than discard earned state. Legacy progress bonus/
   coach/unlocked and monetization last_interstitial/levels_since_purchase remain compatibility
   fields until respective P2 owners switch; no automatic bidirectional synchronization.
3. Default migration chain1→2→3; explicit target chains remain caller-owned. Final structure validated
   before Save exposes sections. Fresh saves start all new fields clean; no reward/config defaults.
4. Validate nonnegative safe integer wallet/items/counter/stars/pieces, unique nonempty transaction/
   coach/postcard/unlock strings; journal JSON objects remain opaque until T-0232. Consent dictionary
   is JSON-safe opaque state owned by Monetization. Ad counters/timestamps/nullable slots and cap
   shape validated; settings volume[0,1], text_scale0..2 and existing typed settings retained.
5. Opaque historical ad-cap dictionaries survive under shop_coins_ads.legacy; nonnumeric historical
   timestamps remain untouched in last_interstitial with new timestamp null. No past interpretation
   is invented. Existing temp-recovery test asserts the current VERSION rather than historical2.
6. Numeric canonicalization covers new fields and dynamic location pieces. Goldens are immutable
   for historical v1/v2; add v3. Existing current-version tests explicitly migrate fixtures before
   validation and preserve original v1→v2 golden assertions via MigrateV1ToV2.migrate; custom future
   test uses VERSION+1. Existing storage recovery and reset behavior unchanged.

## Tests
Golden v2→v3 and complete v1→v3, source/deep-copy isolation, populated multilingual preservation,
never-decrease earned coins/items/transactions; invalid/negative/fractional fields and conflict
rejection; JSON numeric roundtrip, loaded v2 durable retry/recovery, future/missing-version rejection.
Run full make check; fresh exact-head independent review and13CI before sequential squash merge.

## Out of scope
Service transactions/economy journal policy, SDKs, signing, config balance changes and runtime grants.

## Rollback
Do not load newer saves with older builds; backup originals retained by existing storage protocol.
Revert requires retaining v3 read/migration compatibility, not simply decreasing VERSION.
