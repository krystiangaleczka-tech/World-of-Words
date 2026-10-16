---
id: E19
title: IAP and shop
phase: 2
status: active
---

## Goal
Idempotent purchases, permanent Remove Forced Ads and store-backed restore.

## Wave 1
- T-0268: owner catalog/pricing approval and App Store Connect creation; blocked.
- T-0269: native billing plugins; blocked on T-0264 and exact S1 preflight.
- T-0270: deterministic Fake store outcomes; independent of accounts/plugins.

## Decisions
StoreTransaction.store_key remains the store transaction key, never orderId.
Fakes model provider delivery/unfinished state, never wallet grants or Save.
Pending/deferred means no grant. Only purchased transactions can finish.
Real store setup and irreversible product creation remain owner work.

## Open questions
Native plugin versions, device verification and Q6 prices remain external gates.
They do not block unactivated Fake coverage. T-0271 settlement needs a separate
reviewed wave on the merged Fake APIs; it is not implemented by T-0270.

## Exit criteria
T-0275 sandbox device checks pass in both stores.
