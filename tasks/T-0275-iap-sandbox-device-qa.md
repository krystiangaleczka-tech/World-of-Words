---
id: T-0275
title: Verify consumable and non-consumable IAP in both store sandboxes
epic: E19
type: test
area: platform.iap
risk: high
executor: human
think: none
ui: low
status: blocked
depends_on: [T-0273, T-0274]
touch:
  - docs/qa/T-0275-iap-sandbox-devices.md
  - tasks/T-0275-iap-sandbox-device-qa.md
revision: 1
---

## Goal
Certify actual Play Billing internal-track and StoreKit 2 sandbox purchases, restore and crash recovery on physical devices. This is distinct from the already-built Fake transaction tests.

## Context
FR-IAP-02..08/11, FR-ADS-07; TESTING.md#device-checklist; ROADMAP.md T-0275. Canonical P2 IDs: `nc.remove_forced_ads.v1`, `c.coins_s.v1`.

## Current state
T-0272 and T-0273 real provider adapters are blocked; T-0274 shop exists only in explicitly injected mode. T-0268 product approval is blocked. No native sandbox transaction evidence exists on main.

## Specification
Chris tests a build distributed through Play internal testing with license test accounts and an iPhone sandbox/TestFlight configuration with real configured products. Record device/OS, build hash, store account type (not account address), product ID, expected/observed, PASS/FAIL/BLOCKED, transaction identifier **redacted**, screenshots/log links, date.
1. Purchase small coin pack: store-confirmed completion adds exactly configured coins once; retry/duplicate transaction never grants twice; repeat consumable purchase uses a new token.
2. Purchase Remove Forced Ads: entitlement persists after restart and reinstall/restore, removes forced interstitials, does not disable opted-in rewarded.
3. User cancels each purchase: no grant, no entitlement; the sheet leaves loading/pending correctly.
4. Pending Play purchase and deferred Ask to Buy: grant zero before store completion, settle once when eventually approved. Do not simulate provider approval as evidence.
5. Kill/force-stop after store purchase but before acknowledgement/finish, relaunch, fetch unfinished and finish exactly once with durable save; test loss of network mid-flow.
6. Restore Purchases on both platforms recovers **non-consumables only**, not consumable coins; verify iOS Shop and Settings, Android Settings where wired.
7. Reject unverified/invalid purchases, keep entitlement irrevocable locally after grant (FR-IAP-11); no test-mode charge through production personal cards.
8. Confirm consistent shop loading/offline/error localized prices; include audio/ad interplay when entitlement changes.

## Tests
`docs/qa/T-0275-iap-sandbox-devices.md` per-store manual matrix plus pointers to Fake regression suite (T-0270/T-0271), native logs and identity-safe screenshots. Unknown, unavailable and untested are **BLOCKED**, never PASS.

## Acceptance
Both real stores, all required outcomes and exactly-once durable settlement must be demonstrated. T-0273, T-0274, T-0268 and T-0272 prerequisites must be confirmed; no mock-only certification.

## Rollback
Do not reverse granted entitlements or delete published IAP IDs. Disable unverified provider integration before a new review build.
