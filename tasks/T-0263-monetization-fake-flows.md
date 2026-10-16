---
id: T-0263
title: Implement ad presentation and consent flows against Fakes
epic: E18
type: feat
area: services.monetization
risk: high
executor: cheap
think: high
ui: none
status: ready
depends_on: [T-0262, T-0234]
touch:
  - game/services/monetization.gd
  - game/services/monetization/*.gd*
  - game/services/audio.gd
  - game/tests/integration/test_monetization_flows.gd*
  - docs/contracts/monetization.md
  - tasks/T-0263-monetization-fake-flows.md
revision: 1
---

## Goal
Complete the frozen ad APIs with deterministic Fakes before real providers.

## Context
DESIGN.md#flow-rewarded: reward only on reward-earned, not close.
DESIGN.md#flow-interstitial-placement: only campaign Continue after consent.
PRODUCT.md FR-ADS-03..08; roadmap T-0263.

## Current state
Preflight T-0261 exact contract and T-0262 outcome controls after they merge.
Audio has no ad-pause API; game boot remains unactivated for monetization.

## Specification
Use actual readiness callbacks and AdPolicy, Save entitlement and frozen config.
No forced ads with Remove Forced Ads; rewarded remains explicit. Grant through
Economy only once after reward-earned, never close/failure/duplicate callbacks.
Expose unavailable states and finite watchdog cancellation without polling.
Pause/resume Audio only around actual opened/closed/failed ad presentation,
preserving volumes and background/resume correctness. Failed interstitial skips
silently and continuation settles once. Update policy counters only after display.
Do not wire Nav or views in this task; later Level integration owns callers.
Keep IAP APIs fail-closed until T-0271. Stop if implementing requires new config,
save fields or changing the frozen interfaces; do not invent substitutes.

## Tests
game/tests/integration/test_monetization_flows.gd: consent sequencing plus eligible/
ineligible interstitials, entitlement, no-fill, watchdog and retry, every rewarded
outcome/duplicate callback, interrupted grant, audio and app-background lifecycle.

## Out of scope
SDKs, accounts, app permissions, UI, transaction processing, registry/schema changes.

## Acceptance
Every flow tested, no new SDK calls; make check, scope, review and CI pass.

## Rollback
Revert before runtime/real-SDK activation; no save format change.
