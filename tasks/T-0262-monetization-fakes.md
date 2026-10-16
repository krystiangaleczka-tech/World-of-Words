---
id: T-0262
title: Add deterministic ads and consent Fake outcome controls
epic: E18
type: feat
area: platform.ads
risk: high
executor: cheap
think: low
ui: none
status: review
depends_on: [T-0261]
touch:
  - game/platform/ads/ads_fake.gd
  - game/platform/consent/consent_fake.gd
  - game/tests/unit/platform/test_monetization_fakes.gd*
  - tasks/T-0262-monetization-fakes.md
revision: 1
---

## Goal
Provide explicit deterministic outcomes for the T-0261 adapter contract.

## Context
ARCHITECTURE.md#platform: editor/headless use Fakes. Roadmap T-0262.

## Current state
After T-0261, inherited readiness, operation failure and analytics-purpose signals
exist. Fake methods only record calls; outcome delivery is manual.

## Specification
Retain call logging and manual-signal compatibility by default. Add explicit
test/debug outcome selection for info/form/ATT/error, purpose-specific analytics,
SDK readiness, rewarded/interstitial fill/no-fill, reward then close, early close.
Outcomes settle once per operation, without timers, network or grants. Tests must
prove no reward on early close and no callbacks from a superseded operation.

### Interface
- set_outcome(operation: StringName, outcome: StringName, immediate: bool = true)
  returns Error; invalid choices leave the active operation intact. Valid changes
  invalidate pending controlled output while preserving the call log.
- operation_token() returns int (0 after reset/control changes). Each provider
  command starts a new token. settle(token: int) returns bool and settles once;
  use immediate=false to model pending work. Default manual mode never settles
  automatically and inherited signals remain directly usable as before.
- reset() invalidates tokens, clears controls/log and restores manual defaults.
- Ads: initialize ready/error; load_rewarded/load_interstitial ready/no_fill/error;
  show_rewarded reward/early_close/no_fill/error; show_interstitial shown/no_fill/error.
  Every command also supports manual. Show emits opened -> reward (if earned) ->
  closed, checking token validity between callbacks; failure never emits opened.
- Consent: request_info/show_form_if_required/show_privacy_options support unknown,
  required/not_required/obtained/error; request_att supports unknown,
  not_determined/restricted/denied/authorized/error. All also support manual.
- ConsentFake.resolve_analytics(token: int, allowed: bool) returns bool. Only one
  explicit purpose decision per current UMP operation is accepted; ATT, duplicate,
  reset and obsolete tokens are rejected. A new privacy operation can revoke a
  previous decision. UMP/ATT outcomes never infer analytics permission.
- Raw inherited signal emission is the legacy/manual seam; token protection applies
  to the controlled Fake APIs, not arbitrary signals emitted by test callers.

## Tests
game/tests/unit/platform/test_monetization_fakes.gd: every outcome, call ordering,
manual default, exactly-once settlement and reset/reconfiguration isolation.

## Out of scope
SDK, UI, economy, consent policy, service and registries.

## Acceptance
Preflight confirms T-0261 exact interfaces; tests, make check and review pass.

## Rollback
Revert Fake controls before T-0263 callers merge.
