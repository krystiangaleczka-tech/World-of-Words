---
id: T-0260
title: Define deterministic interstitial and prompt budget policy
epic: E18
type: contract
area: core.ads
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0203]
touch:
  - game/core/ads/ad_policy.gd*
  - game/tests/unit/core/ads/test_ad_policy.gd*
  - tasks/T-0260-ad-policy.md
revision: 1
---

## Goal
Ship a pure, testable interstitial eligibility decision and shared session prompt budget,
without initializing providers or adding UI.

## Context
- GAME_DESIGN.md#ad-policy specifies seven required interstitial conditions.
- GAME_DESIGN.md#onboarding exempts UMP, ATT, coach marks and explicit actions.
- PRODUCT.md FR-ADS-01..03, FR-ADS-07 and FR-ONB-04.

## Current state
- No core ads policy exists. AdsAdapter and AdsFake are inert.
- T-0203 is done and game/data/config/ads.json contains canonical starting values.
- T-0261 owns consent and SDK sequencing; T-0263 owns ad display.

## Specification
### Behavior
1. Evaluate only a loaded ad after Continue on a completed campaign level, with
   initialized SDK, resolved consent and no Remove Forced Ads entitlement.
2. Require first-slot, level cooldown, seconds cooldown, session grace, purchase grace,
   including inclusive boundaries. No prior ad or purchase is represented by -1.
3. Classify consent, ATT, coach marks and explicit actions as exempt from the cap.
   Automatic offers, notices, rating prompts and interstitials consume the cap only
   after display; unknown classes fail closed. A zero cap suppresses automatic prompts.
4. Invalid state or config, wrong types or negative elapsed time are ineligible.
   Do not mutate inputs or block a next-level transition.

### Interface
AdPolicy.should_show_interstitial(state: Dictionary, config: Dictionary, now: int) -> bool
AdPolicy.can_show_prompt(kind: StringName, used: int, config: Dictionary) -> bool
AdPolicy.next_prompt_count(kind: StringName, used: int, config: Dictionary) -> int

## Out of scope
Provider integration, showing an ad, save schema, config defaults, analytics and UI.

## Tests
- game/tests/unit/core/ads/test_ad_policy.gd: first slot, seven predicates and boundaries;
  session budget/exemptions and malformed data fail-closed.

## Acceptance
Only allowed files change, the new tests and make check pass in CI.

## Rollback
Revert pure contract before its callers are implemented.

## Escalation log
