---
id: T-0341
title: Expose authoritative durable restore results to Settings
epic: E21
type: contract
area: services.monetization
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0271, T-0328]
touch:
  - game/services/monetization.gd
  - game/services/monetization/iap_flow.gd
  - game/platform/iap/iap_adapter.gd
  - game/platform/iap/iap_fake.gd
  - game/tests/integration/test_restore_results.gd*
  - docs/contracts/monetization.md
  - docs/contracts/settings.md
  - tasks/epics/E21-settings.md
  - docs/qa/T-0341/**
  - tasks/T-0341-restore-results.md
revision: 1
---

## Goal
Give future T-0288 Settings restore UI an authoritative service result rather than
using telemetry for logic or treating accepted dispatch as successful restoration.
This is an independent Phase-2 rolling-wave contract split from T-0288.

## Current state
IapFlow.recover(true) dispatches restore, and T-0328 tracks the optional authoritative
IapAdapter.restore_completed(transactions:Array[StoreTransaction]) terminal batch.
_maybe_restore_completed requires every unique nonconsumable key in committed Save
before emitting analytics. There is no application-facing restore state/result.
Generic purchase_failed cannot distinguish restore from an unrelated purchase.
IapFake suppresses superseded restore terminal callbacks using its operation token.
Monetization forwards purchase state, but restore_purchases only returns acceptance.

## Specification
- IapAdapter adds optional restore_failed(error:Error) for the current restore only.
  Adapters suppress superseded callbacks as with restore_completed. IapFake emits
  it for restore errors only, preserving existing purchase_failed for compatibility
  and rechecking its generation after that callback. Never infer a restore failure
  from unrelated generic purchase_failed.
- IapFlow and Monetization expose restore_snapshot()->Dictionary, restore_changed,
  retry_restore_settlement()->Error and expire_restore()->void. Fresh snapshots
  contain state:StringName, restored_count:int, error:Error, revision:int.
  Service without a flow returns unavailable/-1/ERR_UNAVAILABLE/0.
- Flow starts idle/-1/OK/0; each changed state increments revision and emits the
  dedicated restore_changed notification with reentrant command guards. No Events
  side-effect signal is used for application state. accepted dispatch is requested,
  never completed. Existing wallet, receipt idempotence and acknowledgement rules
  remain unchanged; callbacks can still settle valid receipts after UI timeout.
- Only one observed restore at a time; another restore returns ERR_BUSY without
  provider calls. Explicit IAP/consent reconfiguration is blocked while restore is
  requested/settling. Other existing purchase/unfinished/catalog policies stay.
- Before provider dispatch, start one operation Timer using existing
  AdPresentation.OPERATION_TIMEOUT_SECONDS, ALWAYS and ignore_time_scale. Timer
  expiry or explicit expire_restore produces unknown/-1/ERR_TIMEOUT, stops observing
  and ignores late restore terminal results. Do not revoke or discard receipts.
- Valid final batch stops the provider wait timer. Require PURCHASED nonconsumables,
  trimmed nonempty keys and unique-count dedupe. Invalid batch gives failed/-1/
  ERR_INVALID_DATA without a successful result or partial count. First accepted
  terminal outcome wins; ignore duplicates and late restore_failed after success.
- If batch keys lack committed proof, state is settling with count -1; do not
  expose a count or completed until all proofs exist. Settlement retry only drains
  existing receipts, invokes no restore/fetch/query/purchase, and returns actual
  settlement error. Preserve evidence for retry. Existing unfinished recovery can
  also complete settlement. Completion exposes unique batch count (including zero)
  and keeps existing single iap_restore_completed analytics. New result cannot
  bypass Economy, modify save format, grant value or add analytics events.
- Explicit restore_failed(error) before terminal produces failed/-1/nonzero error;
  OK failure code is normalized to ERR_UNAVAILABLE. Clear timer/evidence on terminal
  failure/timeout. No native SDK activation, secrets, endpoints, UI or boot change.

## Tests
New integration suite with real Save/Economy/Monetization and controlled IapFake:
initial/unconfigured copied snapshots, requested != success, duplicate command and
reconfiguration denial, empty/owned/duplicate-key completed counts, malformed and
consumable batch rejection, failed durable write with retry/no second provider
command/no early finish, unrelated purchase failure isolation, explicit restore
failure, timeout then late batch/valid receipt, duplicate/first-terminal behavior,
reentrant command guards, real Timer signal/configuration, notification-time expiry
without obsolete dispatch, and Fake superseded-error generation suppression.
Full make check, fresh independent review and all exact-head CI green.

## Acceptance
Results come from service-owned authoritative evidence, not analytics. Native
adapters must implement terminal result/failure suppression before UI can claim
their result. Settings UI/global activation and physical store gates remain open.

## Rollback
Squash revert removes transient result API/signals; no saved schema/value changes.
