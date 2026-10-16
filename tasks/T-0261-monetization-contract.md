---
id: T-0261
title: Define explicit consent sequencing and fail-closed monetization APIs
epic: E18
type: contract
area: services.monetization
risk: high
executor: sol
think: xhigh
ui: none
status: review
depends_on: [T-0260, T-0229, T-0233, T-0250]
touch:
  - game/services/monetization.gd
  - game/platform/consent/consent_adapter.gd
  - game/platform/ads/ads_adapter.gd
  - game/tests/integration/test_monetization_contract.gd*
  - docs/contracts/monetization.md
  - tasks/epics/E18-consent-and-ads.md
  - tasks/T-0261-monetization-contract.md
  - tasks/T-0262-monetization-fakes.md
  - tasks/T-0263-monetization-fake-flows.md
revision: 1
---

## Goal
Freeze the service boundary and verify consent ordering against existing Fakes.
Keep the shipped game unchanged until T-0263 explicitly activates these flows.

## Context
- DESIGN.md#flow-consent-and-att: "Both steps happen on the Level complete layer,
  after the player taps Continue and before the next level appears."
- PRODUCT.md FR-ADS-06: "Ad SDK initializes only after the UMP flow resolves;
  on iOS no ad is requested before ATT resolves."
- ARCHITECTURE.md#monetization-flows: ads SDK initialization after consent/ATT.
- AGENTS.md: Events is for side effects, never game logic.
- Roadmap T-0261; T-0262 supplies outcome controls, T-0263 implements ad display.

## Current state
- Monetization is an inert ServiceStub; no boot/view caller invokes it.
- AdPolicy exists with campaign-only gates and a shared automatic prompt budget.
- ConsentAdapter has consent_resolved/att_resolved and explicit info/form/ATT methods,
  but no purpose-specific analytics result or operation failure signal.
- AdsAdapter has reward-earned/closed/failed and rewarded-loaded signals, but no
  initialization/interstitial readiness or actual-open notification.
- Save, Economy, Clock, Events.consent_changed and frozen config keys are merged.

## Specification
1. Explicitly configure loaded Save/Config, Events and an injected ConsentAdapter,
   AdsAdapter and iOS flag. No work on construction/ready; no boot wiring here.
   Reject configuration while any adapter operation or Continue is active; otherwise disconnect
   old callbacks and reset session consent state. No Save mutation.
2. start_session requests info once, silently. A required form is held until
   before_next_level(completed_slot), with slot >= consent.ump_after_slot.
   Only positive campaign-completion slots are accepted; another active call is busy.
3. One Continue owns one flow: info -> required form -> iOS ATT when slot >=
   consent.att_after_slot -> SDK initialize -> continuation_ready(slot).
   iOS initialization is conservatively delayed until ATT resolves, satisfying both
   PRODUCT and ARCHITECTURE. Earlier iOS Continue releases without initializing ads.
   Android skips ATT. NOT_REQUIRED/OBTAINED UMP and terminal ATT outcomes resolve steps.
4. Adapter operation failure or explicit expire_operation releases Continue, leaves
   consent unresolved and forbids SDK readiness. Next Continue retries info/form/ATT.
   UNKNOWN and NOT_DETERMINED are unresolved; duplicate/unsolicited callbacks must
   not resume or initialize twice. Adapters own callback correlation per operation.
5. Add ConsentAdapter.analytics_resolved(allowed: bool), relayed only as an explicit
   purpose-specific provider/legal result to Events.consent_changed. Never infer
   analytics permission from UMP enum or ATT authorization. Add operation_failed.
6. Add AdsAdapter initialized, interstitial_loaded and ad_opened signals. The service
   distinguishes issuing initialize from receiving initialized; failures fail closed.
7. Contract API request_rewarded, purchase, restore_purchases and
   process_unfinished_transactions return ERR_UNAVAILABLE without provider calls,
   rewards or writes until their separately owned implementations. Reward availability
   is unavailable here. audio_pause_requested is the future presentation boundary.
8. can_offer_interstitial(state) calls AdPolicy with current SDK readiness and the
   Save-owned Remove Forced Ads entitlement overriding caller data. It remains false
   until T-0263 supplies actual loaded-ad state; no interstitial is shown in T-0261.
9. No timers, polling, network, SDK installation, registry/config/economy/schema changes.
   expire_operation is the explicit cancellation/timeout seam for later presentation.
   For real SDK activation, T-0263 must supply a finite watchdog before calling it.

## Interface
Exact signatures and states: docs/contracts/monetization.md.
before_next_level receives the completed slot, never the next slot.
continuation_ready is the domain completion signal; Events only reports consent.

## Tests
game/tests/integration/test_monetization_contract.gd:
- Silent info refresh, slot-1 UMP timing, Android order and slot-6 iOS ATT order.
- Required form, not-required region, denied/restricted/authorized ATT, unresolved
  retry, operation failure/expiry, duplicate callbacks and busy reentry.
- Separate analytics true/false relay; UMP/ATT alone emit no analytics decision.
- Old adapter teardown/reconfiguration; readiness only after initialized.
- Fail-closed rewarded/IAP/policy APIs, no grants or Save mutations, no automatic boot work.

## Out of scope
T-0263 owns actual rewarded/interstitial presentation, audio pause and watchdog.
T-0271 owns transaction processing, grants/flush/finish and entitlements.
T-0264/65 own real SDK/provider and physical-device validation. No Nav/UI wiring here.

## Acceptance
All contract tests, make check, independent review and CI pass within touch.
The T-0261–0263 wave is documented without editing ROADMAP. Existing CI requires
t/NNNN branches; specification and implementation are reviewed together here.

## Rollback
Revert this unactivated service contract before T-0262/0263 depend on it.
