---
id: T-0274
title: Compose an explicit Shop Sheet over owned monetization state
epic: E19
type: feat
area: features.shop
risk: high
executor: sol
think: high
ui: high
status: ready
depends_on: [T-0271, T-0217, T-0334]
touch:
  - game/features/shop/*.gd*
  - game/features/shop/*.tscn
  - game/services/monetization.gd
  - game/services/monetization/iap_flow.gd
  - game/services/monetization/ad_presentation.gd
  - game/locale/shop.csv*
  - game/tests/integration/test_shop_sheet.gd*
  - docs/qa/T-0274/**
  - docs/contracts/monetization.md
  - tasks/T-0274-shop-sheet.md
  - tasks/T-0278-paid-tools.md
revision: 1
---

## Goal
Provide an explicitly injected, unactivated Shop Sheet with real owner-derived
balances/entitlement, provider prices and purchase/reward states.

## Context
DESIGN.md#shop-sheet/#flow-purchase and FR-IAP-01/06; mockup
 docs/design/T-0205/evidence/shop_COMPACT_PL_default.png.
No fake price is shown as a live store offer; no provider/account setup is inferred.

## Current state
Sheet/Card/Primary/Secondary/CurrencyPill/TextButton exist. T-0334 supplies footer
variant/value support. Monetization has explicit IAP binding and per-receipt state,
rewarded cap and Economy grant binding. No Shop scene/product-catalog presentation
API exists. No provider batch-completion callback exists.

## Specification
Create ShopSheet composed only from existing catalog controls. configure(monetization,
ios:bool) injects the service; open requests product prices explicitly. Scene remains
unmapped in Nav/boot. Show Remove Forced Ads Card, configured coin amount Card, free
rewarded coin Card and iOS-only Restore. One Primary: remove ads until owned, then
coin pack. Prices come only from valid provider product id/price string fixtures;
missing/loading/offline price disables purchase. Owned remove ads never repurchases.

Monetization owns copied shop_snapshot, request_products and request_shop_reward
APIs/signals; it binds actual same-Save Economy from configure_iap. Product requests
use finite 120s technical watchdog. Forward ready/failure, durable wallet, entitlement,
IAP and ad-state changes without polling. Never use provider amounts for grants.
Snapshot exposes actual local-day cap and enabled/readiness state. Reward retry after
failed write calls same earned grant, without another ad/cap increment.

UI exposes loading/offline/pending/success/failed/cancelled/owned/unavailable/capped
via translated captions. Deferred maps to frozen PENDING. Unknown remains unresolved.
Restore is a request, not fabricated batch success: finite presentation may clear
loading to unknown and never invent completion when no receipt arrives. Adapters own
restore filtering. New requests cannot bypass owner busy guards. Closing/reopening
reads retained current state; no duplicated callbacks/actions. Persistent grant is
owned exclusively by Monetization/Economy, never the view.

## UX rules
R-UI-1/2 existing catalog; R-UI-3 tokens; R-UI-4 static locale keys/provider data;
R-UI-5 no generated themes; R-UI-6 native three classes xPL/PSEUDO xdefault/HC130
screenshots with mockup comparison. Device/taste evidence remains Chris's pending
release gate, consistent with T-0245/T-0246; desktop does not certify it.

## Tests
Actual service/Fakes integration: prices/no price/failure, owned/primary swap,
coin purchase, pending/deferred/failure/cancel, restore iOS-only, reward success/
no-fill/cap/retry, close/reentry, copied snapshots, keyboard/native intent and
12-case layout/scroll/HC130/PSEUDO matrix. No P1/boot/SDK activation.

## Acceptance
Full checks, scope, fresh review, all CI green; QA screenshots and explicit open
device gate. Native SDKs, store approvals, Nav mapping and paid tools out of scope.
