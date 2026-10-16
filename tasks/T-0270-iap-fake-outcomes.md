---
id: T-0270
title: Add deterministic IAP Fake outcomes and unfinished-store replay
epic: E19
type: feat
area: platform.iap
risk: high
executor: cheap
think: med
ui: none
status: review
depends_on: [T-0261]
touch:
  - game/platform/iap/iap_fake.gd
  - game/tests/unit/platform/test_iap_fake.gd*
  - docs/contracts/iap-fake.md
  - tasks/T-0270-iap-fake-outcomes.md
  - tasks/T-0268-iap-catalog-approval.md
  - tasks/T-0269-billing-plugins.md
  - tasks/epics/E19-iap-and-shop.md
revision: 1
---

## Goal
Exercise purchase delivery, duplicate transaction keys and interrupted finish without
accounts, SDKs, wallet grants or UI. Include the three-row E19 planning wave.

## Context
PRODUCT.md FR-IAP-03: idempotence uses purchaseToken / Transaction.id, never orderId.
FR-IAP-04: grant, atomic flush, then finish. FR-DEBUG-03 requires fake cancel,
pending and crash-before-finish controls. Roadmap T-0270.

## Current state
- IapFake extends IapAdapter, logs query_products/purchase/finish/fetch_unfinished/restore.
- Inherited products_received, transaction_updated and purchase_failed signals exist.
- StoreTransaction has store_key/product_id/state; PURCHASED/PENDING/CANCELLED/FAILED.
- Default manual delivery is used by existing tests and must remain unchanged.
- T-0261 is merged (#189); IAP service APIs remain fail-closed.

## Specification
Add per-instance validated set_outcome(operation, outcome, immediate=true),
operation_token(), settle(token), reset(), simulate_restart() and copied product
fixtures via set_products(products). Existing adapter signatures do not change.
Manual is default. Query accepts ready/error; purchase accepts success, cancel,
pending, deferred, failed, crash_before_finish, duplicate. Fetch/restore accept ready/error.
Invalid controls return ERR_INVALID_PARAMETER without invalidating a pending request.
Accepted commands, control changes, reset/restart supersede pending controlled output;
finish only acknowledges its matching purchased key and must not cancel delivery.
One token settles at most once; synchronous observers may cancel remaining callbacks.

Success creates a unique deterministic purchased key. Duplicate sends two detached
copies of the same purchased transaction, not two purchases. Pending/deferred emit
PENDING and never imply entitlement; subsequent set_transaction_state(key,state)
can mark PURCHASED for explicit fetch replay or CANCELLED to remove a pending record. Failed/cancel emit terminal
transaction states; failed also emits purchase_failed. Unknown/empty product fails closed.
Product fixtures require unique non-empty string id and restorable: bool; other
localized metadata is opaque and deeply copied. Only fixture-known products purchase.

Store unfinished purchased/pending transactions independently of callbacks. finish
removes only matching purchased state, idempotently. crash_before_finish emits a
purchase but ignores its finish attempts until simulate_restart, preserving its key
for fetch_unfinished. This models an interrupted acknowledgement, not an OS kill.
Restart invalidates tokens and clears the finish interruption but retains provider
records, product fixtures, controls, sequence and call log. Full reset clears them.
Restore replays owned purchased restorable products, including finished purchases;
consumables never restore. Sort replay by key and snapshot batches before emitting.
Every emitted transaction and product list is detached from internal state.
No Save, Economy, service activation, real provider calls, file I/O or actual crash.
Document the control APIs and limitations in docs/contracts/iap-fake.md.

## Tests
New unit suite covers manual call-log compatibility, validated controls/fixtures,
all purchase outcomes, deterministic unique keys, token one-shot/stale/reset/restart,
copy isolation, observer reentry, unfinished replay and exact-key finish, pending
completion/cancellation, interrupted finish restart, and restore non-consumables only.
Existing platform contract tests must pass without edits.

## Acceptance
Required tests, make check, scope, independent review and all CI checks pass.
No adapter/envelope/config/save schema changes. T-0268/T-0269 remain blocked.

## Rollback
Revert before real providers or service settlement activation; no persisted data.
