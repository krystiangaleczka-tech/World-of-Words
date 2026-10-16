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
status: ready
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

## Tests
game/tests/unit/platform/test_monetization_fakes.gd: every outcome, call ordering,
manual default, exactly-once settlement and reset/reconfiguration isolation.

## Out of scope
SDK, UI, economy, consent policy, service and registries.

## Acceptance
Preflight confirms T-0261 exact interfaces; tests, make check and review pass.

## Rollback
Revert Fake controls before T-0263 callers merge.
