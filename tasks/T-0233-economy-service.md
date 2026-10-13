---
id: T-0233
title: Persist reasoned Economy transactions and bounded journal
epic: E15
type: feat
area: services.economy
risk: high
executor: cheap
think: med
ui: none
status: done
depends_on: [T-0232]
touch:
  - game/services/economy.gd
  - game/tests/integration/test_economy_service.gd*
  - tasks/T-0232-economy-service-contract.md
  - tasks/T-0233-economy-service.md
  - docs/qa/T-0233-economy-service.md
revision: 1
---

## Goal
Implement the merged T-0232 service contract with durable wallet and bounded journal operations.
Owner authorized creating and executing this missing task, and merging T-0232.

## Current state
T-0232 typed inert Economy methods and Events.economy_changed are merged.
Save.set_section validates/copies the whole section, then flush persists dirty memory synchronously;
failed writes leave it retryable, and other Save owners may flush it. SaveSchema v3 journals accept
opaque dictionaries; unknown extensions remain preserved. Clock is inherited from ServiceStub.
Config has has_key/get_int, no is_loaded; readiness uses presence of the required journal key.
WalletSnapshot provides pure granted/spent arithmetic. No runtime Economy caller exists yet.
Reconcile merged T-0232 status to done as explicit task bookkeeping.

## Specification
1. Inject concrete Save/Config/Events without reads or writes in configure. Require loaded Save,
   Clock, positive configured economy.journal.max_entries and a valid known wallet before mutations.
   Missing dependencies return existing unconfigured defaults. No boot wiring or new APIs.
2. grant/spend validate trimmed nonempty reasons and WalletSnapshot flat amounts. Compute one
   independent candidate, preserving bonus_counter/unknown fields and legacy journal entries.
   Append {timestamp, operation, reason, amounts}, timestamp from Clock; trim oldest to configured
   bound. Persist via set_section then flush. No schema/config/economy-value changes.
3. Serialize the entire write/publication path, rejecting reentrant mutations. configure during
   a transaction or pending retry is ignored so it cannot discard unresolved work.
4. On set_section rejection do not retain a pending request. On flush failure retain before/candidate
   and operation. Public reads show before state; affordability false until retry. Only identical
   operation/reason/amounts may retry; another request returns ERR_BUSY/false without writing.
   Retry flushes the exact candidate, never applies arithmetic/journal twice, even after another
   owner flushed it. If another owner replaces economy, discard stale pending on retry and return
   ERR_BUSY without overwriting the replacement; the next explicit request uses the live state.
5. Clear pending before publishing once after durable success; keep reentrancy guard through callbacks.
   Signal dictionaries are independent of service/Save/request state. Restart reads whichever complete
   Save document won atomic recovery: no partial wallet/journal. Journal is diagnostic, not an
   idempotency key: operation identity across restart and gameplay reward dedup remain future callers.
   Do not integrate paid actions or completion/bonus rewards before their joint transaction tasks.

## Tests
New test_economy_service.gd: unready/invalid dependencies and payloads; mixed grant/spend and
insufficiency/overflow atomicity; timestamps/bound/legacy extensions and copy isolation; failed
set and failed flush; identical retry/different request; external flush; conflicting replacement;
reentrant flush/signal/configure; restart old-or-one candidate with real isolated SaveStorage.
Existing unconfigured contract tests remain unchanged. Full make check and scope/task checks.

## Rollback
No gameplay callers: revert service implementation without rewriting existing Save documents.
