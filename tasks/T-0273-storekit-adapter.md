---
id: T-0273
title: Implement verified StoreKit 2 transaction delivery
epic: E19
type: feat
area: platform.iap
risk: high
executor: cheap
think: xhigh
ui: none
status: blocked
depends_on: [T-0272]
touch:
  - docs/qa/T-0273-provider-preflight.md
  - tasks/T-0273-storekit-adapter.md
revision: 1
---

## Goal
Deliver locally verified store transactions through the frozen IapAdapter envelope.

## Context
PRODUCT.md FR-IAP-08: local verification, no backend. Roadmap T-0273.
AGENTS.md S7/S11 apply. Real account/product/signing/device work is owner-assisted.

## Current state
IapFake and explicit service settlement are separate from native transports.
Release gates: merged T-0272, exact StoreKit plugin baseline and Chris iPhone build loop. These gates are not certified by this planning record.

## Specification
Blocked preflight only. Before ready, inspect exact merged native plugin APIs,
verification behavior, transaction-key mapping and platform build evidence. Revise
this task with smallest exact code/plugin/settings touch paths and device tests.
Emit only locally verified PURCHASED transactions; pending/cancel/failure cannot
imply entitlement. Restore emits verified non-consumables only. Use purchaseToken
or Transaction.id, never orderId. Fetch unfinished at activation and correlate stale
operations. Do not mutate provider settings or introduce credentials from this record.

## Tests
Executable revision must cover verification rejection, pending/deferred, duplicate
keys, unfinished restart and restore in sandbox on the actual target device.

## Acceptance
Stay blocked until exact preflight scope and every roadmap gate are verified. Add
missing roadmap dependency IDs to metadata when their task files materialize.

## Rollback
Disable provider selection before reverting; retain processed keys and entitlement.
