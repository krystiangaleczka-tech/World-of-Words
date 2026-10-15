---
id: T-0256
title: Test consent order and monotonic feature unlock thresholds
epic: E17
type: test
area: services.config
risk: low
executor: cheap
think: low
ui: none
status: review
depends_on: [T-0255, T-0234]
touch:
  - game/tests/integration/test_config_timeline_constraints.gd*
  - tasks/T-0256-config-timeline-constraints.md
revision: 1
---

## Goal
Fail automated CI if the shipped config schedules either consent prompt too late,
exposes an ad before ATT, or reorders the onboarding feature unlock timeline.

## Context
- docs/PRODUCT.md#first-10-minutes-timeline — "Consent and ATT are resolved before the first moment an ad could be offered."
- docs/DESIGN.md#feature-unlock-gating — gated features are controlled by config.
- docs/GAME_DESIGN.md#unlocks — at-slot/after-slot semantics.
- tasks/ROADMAP.md T-0256 — strict timeline inequality and monotonic unlocks.

## Current state
- Config.load() supplies typed shipped defaults and can be instantiated in GUT.
- Consent, unlock and interstitial slot keys already exist in data/config JSON.
- T-0234's integration test verifies individual defaults and some ordering assertions,
  but does not check every monotonic unlock boundary, inclusive UMP <= ATT,
  or negative mutation cases.
- RemoteConfigContract.validate() (T-0254) rejects protected nonremote keys.
- T-0254 (#182) and T-0255 (#183) are merged; the remote runtime is available on main.

## Specification
1. Verify the shipped Config service satisfies
   consent.ump_after_slot <= consent.att_after_slot <
   min(unlocks.hint_slot, unlocks.double_reward_slot, ads.interstitial.first_slot).
2. Verify these onboarding slots are nondecreasing:
   shuffle, bonus_meter, hint, journey, reveal, double_reward, daily.
   Preserve the canonical defaults from PRODUCT.md, including the
   intentional reveal/double_reward tie at slot 12 and interstitial after daily.
3. Mutation regressions must fail for reversed UMP/ATT, ATT at any one of the
   three first-offer gates, and each reversed unlock pair. UMP=ATT is valid.
4. Verify all consent, unlock and first interstitial keys are integer, remote=false
   in their shipped registries and rejected as remote overrides.
5. No production config, values, APIs, schema, or runtime behavior are changed.

## Tests
File: game/tests/integration/test_config_timeline_constraints.gd
- test_shipped_config_obeys_consent_and_onboarding_constraints
- test_consent_equal_slots_are_allowed_but_reversed_order_is_not
- test_att_must_precede_each_of_the_three_ad_offer_thresholds
- test_every_unlock_edge_rejects_reversal_and_accepts_ties
- test_remote_config_rejects_all_consent_unlock_and_first_ad_slot_keys

## Acceptance
- All five GUT tests pass.
- CI catches a violation in any actual shipped slot gate.
- Only the allowed test/script UID and task file changed relative to main.
- Merge only after T-0255 is merged and this branch is updated onto main.

## Escalation
S1 dependency exception resolved — #182 and #183 are merged. This test-only branch
was mechanically rebased onto main without conflicts. The owner requested completing
the next roadmap task; pinned gdformat is available to resolve the prior formatting block.
