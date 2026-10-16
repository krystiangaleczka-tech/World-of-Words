# IAP Fake controls (T-0270)

IapFake keeps the frozen IapAdapter operations and StoreTransaction envelope.
Default operations only record calls; tests may still emit inherited signals.
No SDK, disk, Economy, Save, real verification or service activation is involved.

## Fixtures and controls

- set_products(products: Array[Dictionary]) -> Error: atomically replace copied
  fixtures. Each needs a unique non-empty trimmed string id and restorable: bool.
  Remaining metadata (including localized display price) is opaque and copied.
  Only fixture-known products can produce controlled purchases.
- set_outcome(operation: StringName, outcome: StringName, immediate: bool = true)
  -> Error: configure one operation on this instance. manual and error apply to
  all operations. query_products/fetch_unfinished/restore additionally accept ready;
  purchase accepts success/cancel/pending/deferred/failed/crash_before_finish/duplicate.
- operation_token() -> int and settle(token: int) -> bool: defer controlled
  output with immediate=false, then explicitly settle it once. No sleeps/polling.
- set_transaction_state(key: String, state: StoreTransaction.State) -> Error:
  progress an existing PENDING record to PURCHASED for explicit fetch replay, or
  CANCELLED to remove it. This fixture control emits no callbacks by itself.

Invalid controls/fixtures/progression return ERR_INVALID_PARAMETER and leave
pending delivery untouched. Accepted adapter commands, fixture/control changes,
progression, reset and restart invalidate obsolete output. finish does not cancel
provider delivery. A synchronous observer changing generation cancels the remainder
of a multi-callback operation. Replay snapshots are sorted by store_key; finishing
one callback does not truncate the rest. All callbacks carry detached data.

## Provider state and recovery

Successful purchases have deterministic unique fake_iap_N keys per instance.
Pending and deferred both use PENDING; neither represents an owned entitlement.
Cancel and failed produce terminal envelopes and no unfinished record. failed also
emits purchase_failed("failed"); generic error and unknown_product emit only failure.
Duplicate emits two detached PURCHASED envelopes with the same key.

finish logs a detached envelope and removes only the exact matching purchased
key/product/state. Pending, mismatched, null, repeated or unknown finishes cannot
acknowledge another purchase. Finished restorable ownership remains available to
restore, while consumables are excluded. Multiple provider keys stay distinct;
the settlement owner must enforce gameplay idempotence in T-0271.

crash_before_finish emits PURCHASED but ignores finish attempts until
simulate_restart() -> void. This models interrupted acknowledgement without killing
the process. Restart cancels callbacks and clears the interruption while preserving
provider transactions, ownership, products, controls, sequence and call log. Fetch
then redelivers the same unacknowledged key. This is an in-memory model, not durable
process-death storage. reset() -> void clears all provider state, fixtures, controls,
sequence and calls for a new isolated test universe; tokens remain invalidated.

Runtime debug views and real store adapters are later tasks. No new public
IapAdapter signature, transaction state, config key, product ID or save field.
