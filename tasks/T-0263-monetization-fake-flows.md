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
status: review
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

### Implementation refinements
- Frozen public Monetization signatures remain unchanged. The reward callable is
  bound Economy.grant(source, amounts) for this Save, with copied arguments and an
  Error result. Only reward-earned may invoke it. Identical failed settlement can
  be explicitly retried without a second ad; reentry returns ERR_BUSY.
- A named 120-second technical operation watchdog drives expire_operation. Both
  one-shot Timers ignore Engine.time_scale and scene pause. This is a cancellation
  safety deadline, not a new balance/config value. No polling or sleeps.
- hint, double_reward and shop_coins are supported. Shop coin amount/cap come from
  existing config; the existing per-local-day cap is reserved durably after reward
  earned and before wallet grant. Reservation/write retry cannot count twice.
- No process-death exactly-once ad entitlement is claimed: that would require a
  durable reward journal beyond this task. Live write failures remain retryable.
- Interstitial history uses existing last_interstitial_time/levels_since_interstitial,
  plus session-only monotonic cooldown and prompt counts. Restarts may conservatively
  delay an ad when historical campaign-slot evidence is unavailable; never infer a
  precise past slot or rewrite legacy fields.
- Audio.bind_monetization(source) observes the existing pause signal; ad pause and
  application background are separate reasons, without changing saved volumes.

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
