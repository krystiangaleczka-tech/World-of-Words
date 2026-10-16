---
id: T-0271
title: Settle verified purchases with durable wallet and transaction-key idempotence
epic: E19
type: feat
area: services.monetization
risk: high
executor: sol
think: xhigh
ui: none
status: review
depends_on: [T-0270, T-0263]
touch:
  - game/services/monetization.gd
  - game/services/monetization/iap_flow.gd*
  - game/services/economy.gd
  - game/services/save.gd
  - game/tests/integration/test_iap_settlement.gd*
  - docs/contracts/monetization.md
  - tasks/T-0271-iap-settlement.md
  - tasks/T-0272-play-billing-adapter.md
  - tasks/T-0273-storekit-adapter.md
  - tasks/epics/E19-iap-and-shop.md
revision: 1
---

## Goal
Process verified store updates exactly once by store_key, through a durable paired
wallet/processed-key document before acknowledgement. Remain unactivated in boot.
Include E19 wave 2 planning; native adapters stay blocked on external prerequisites.

## Context
PRODUCT.md FR-IAP-02..07/11, FR-SAVE-08, NFR-13; ARCHITECTURE.md#monetization-flows:
"A crash between any two steps must neither lose nor double a grant."
Remove Forced Ads is permanent; processed_transactions is never trimmed.
Roadmap T-0271; accepted sources remain unchanged.

## Current state
T-0270 (#192) and T-0263 (#191) are merged. IapAdapter exposes transaction_updated,
purchase_failed, purchase/restore/fetch_unfinished but no batch-completion signal.
Monetization's three IAP methods fail closed and consent configure is frozen.
Economy owns wallet grants and shared batch preparation, serializes pending work.
Save has set_section, flush, committed_view and existing monetization fields.
AtomicRequest/AtomicSave authorize campaign completion only; do not widen them.

## Specification
### Explicit interfaces
- Save.stage_purchase(economy: Dictionary, monetization: Dictionary) -> Error:
  validate the full paired candidate before changing either section; no I/O/signals.
- Economy.grant_purchase(store_key: String, product_id: String) -> Error:
  transaction-specific extension of the existing Economy grant owner using its
  batch grant logic; grant/spend signatures remain unchanged. Build wallet/entitlement,
  append existing key, update last_purchase_slot from committed current-language
  progress and set legacy levels_since_purchase=0. One paired stage and flush.
- Monetization.configure_iap(economy, adapter: IapAdapter) -> Error: explicitly bind
  same-Save Economy and store after consent configure, without provider calls.
- purchase_state() -> StringName and purchase_state_changed(product_id: String,
  state: StringName, error: Error) expose idle/purchasing/pending/settling/completed/
  cancelled/failed/unknown. Existing purchase, restore_purchases,
  process_unfinished_transactions signatures remain unchanged.

Only PURCHASED can grant/finish. Valid nonempty trimmed store_key is the idempotency
key, never orderId. Known canonical products only: nc.remove_forced_ads.v1 permanently
sets entitlement; c.coins_s.v1 grants current configured iap.coins_s.amount, ignoring
provider amounts. Processed-key duplicates grant nothing and only finish after a
committed-view proof; dirty marker never authorizes finish. Unknown/malformed updates
fail closed. Pending/deferred/cancel/failure cannot grant or finish.

The wallet and key must reach durable storage in one document; no schema change,
new journal format, or separate grant-then-key flush. Pending Economy purchases hide
uncommitted wallet changes, block all other wallet requests/atomic prepare/configure,
and allow same-key retry. If another owner flushes the dirty paired candidate after
an error, reconcile the pending Economy operation and publish its notification once
before finish. Retry preserves unrelated current fields and true entitlements.
Do not mark an incomplete or conflicting candidate complete.

Serialize copied callbacks and queue failed purchased updates for explicit recovery.
Reentrant signals cannot nest grant/finish or replace active owners. Provider pending
transactions block another purchase of that product, not receipt processing. Explicit
recovery retries pending settlement then fetches unfinished through the same owner.
Restore requests provider non-consumables; adapters must emit only verified restorable
ownership from restore. Ordinary verified updates may arrive independently; no batch
completion can be inferred from a callback. No fabricated completion signals.

A finite one-shot 120-second technical Timer may mark unanswered purchase unknown
without releasing its product for another purchase; callbacks/recovery remain valid.
No polling/sleeps. Successful local settlement means durable grant + finish requested,
not proof of provider acknowledgement. Unfinished replay handles lost acknowledgement.
Configure performs no automatic boot fetch; later activation must explicitly call it.

## Tests
New integration suite with actual Save/Economy and IapFake covers:
- configured coin amount, paired durable key and finish ordering, duplicate key;
- permanent entitlement, restore after finish, no consumable restore;
- pending/deferred to purchased, cancellation/failure/unknown/malformed inputs;
- blocked flush and same-key retry with no extra grant; foreign-owner/reentry guards;
- failed flush followed by another owner's successful flush, then replay reconciliation;
- each storage checkpoint crash/reload: old pair or new pair, one eventual grant;
- crash before grant and after durable grant/before finish via Fake interrupted finish;
- no boot/provider activation, finite timeout, old configured adapter disconnection.
Existing tests remain unchanged and pass.

## Acceptance
Task scope, independent fresh review, make check and all CI pass. Escalate for Opus
only if fresh review leaves an unresolved concern (roadmap merge rule 7).

## Out of scope
SDKs, provider verification implementation, prices/catalog approval, UI, analytics
producers, new schema/config/dependency, campaign atomic contract changes.

## Rollback
Before activation a revert restores fail-closed APIs; existing persisted keys and
entitlement must not be cleared. Never erase processed keys to replay a purchase.
