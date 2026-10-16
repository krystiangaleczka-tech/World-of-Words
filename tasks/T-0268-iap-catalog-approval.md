---
id: T-0268
title: Approve P2 IAP catalog and record store setup
epic: E19
type: docs
area: store
risk: high
executor: human
think: none
ui: none
status: blocked
depends_on: [T-0248]
touch:
  - docs/store/T-0268-iap-catalog.md
  - tasks/T-0268-iap-catalog-approval.md
revision: 1
---

## Goal
Record Chris's approval of Q6 prices and the P2 catalog before irreversible creation.

## Context
PRODUCT.md#iap-catalog: product IDs cannot be reused after deletion.
FR-IAP-01 requires store-localized prices. Roadmap T-0268.

## Current state
PRODUCT.md proposes nc.remove_forced_ads.v1 and c.coins_s.v1; Q6 is owner-owned.
T-0259 store/account prerequisite is not delivered. No completion is inferred.

## Specification
After dependencies are verified, Chris approves IDs, content and per-store prices,
then creates the non-consumable and consumable in App Store Connect. Record only
non-secret evidence, date, approval and resulting status in the allowed report.
Play product creation belongs to T-0272. Do not invent prices or access credentials.

## Tests
Review the report against the two canonical PRODUCT IDs and dependency evidence.

## Acceptance
Owner approval and actual App Store Connect setup are documented; no placeholders
are marked complete. Remains blocked until owner/prerequisite evidence exists.

## Rollback
Documentation can revert; created store IDs cannot be deleted/reused as a rollback.

## Planning dependency gate
The roadmap prerequisite is described above but has no task file yet. Add that
ID to depends_on when materialized; status must remain blocked until it merges.
