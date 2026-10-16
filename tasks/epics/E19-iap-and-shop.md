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

## Wave 2
- T-0271: durable Fake-backed purchase settlement on merged T-0270/T-0263.
- T-0272/T-0273: native verified adapters, blocked planning records only.

## Wave 3
- T-0334: separate Card footer/value states required by R-UI-1/2.
- T-0274: explicitly injected Shop Sheet, after T-0334.
- T-0275: future HUMAN device test after real adapters/shop, not certified here.

## Decisions
StoreTransaction.store_key remains the store transaction key, never orderId.
Fakes model provider delivery/unfinished state, never wallet grants or Save.
Pending/deferred means no grant. Only purchased transactions can finish.
Real store setup and irreversible product creation remain owner work.

## Open questions
Native plugin versions, device verification and Q6 prices remain external gates.
They do not block unactivated Fake-backed settlement. Native preflights require
exact plugin/device evidence before their task scope can be released.

## Exit criteria
T-0275 sandbox device checks pass in both stores.
