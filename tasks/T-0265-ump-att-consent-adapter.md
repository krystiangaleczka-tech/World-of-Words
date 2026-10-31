---
id: T-0265
title: Connect UMP and iOS ATT consent adapters with privacy options
epic: E18
type: feat
area: platform.consent
risk: high
executor: cheap
think: high
ui: low
status: blocked
depends_on: [T-0264, T-0263]
touch:
  - docs/qa/T-0265-consent-preflight.md
  - tasks/T-0265-ump-att-consent-adapter.md
revision: 1
---

## Goal
Bind real UMP and ATT outcomes into the existing frozen Monetization consent flow, with no advertising request before the applicable decisions resolve.

## Context
- FR-CONSENT-01: refresh UMP consent info on every launch, form after slot 1 when required.
- FR-CONSENT-03: Settings privacy options reopens UMP form if required.
- FR-CONSENT-04: ATT after slot 6, after UMP's explainer and before the first iOS ad request.
- DESIGN.md#flow-consent-and-att; ROADMAP.md T-0265.

## Current state
Fake sequencing exists in T-0263; real T-0264 native bridge and iPhone evidence do not. Privacy-options UI belongs to T-0288/Settings; never create an incompatible Settings surface here.

## Specification
1. Before unblocking, inspect merged T-0264 plugin APIs, exact existing `ConsentAdapter` contract, signal/error mapping and real iPhone build loop. Revise with precise adapter paths/touch globs, no new globals.
2. UMP consent info is requested per launch; only show a required consent form at the frozen game slot; initial ad initialization waits for resolved consent. Retry transient failures without manufacturing an affirmative decision.
3. On iOS, show UMP-provided IDFA explainer before native ATT at its configured slot; denial still permits eligible non-personalized ads after resolution. Never request ATT on Android or first launch.
4. Expose real privacy-options reopen state; no new custom pre-prompt, analytics name, save field or consent bypass.
5. Preserve Fake adapter selection and the pre-existing Monetization order.

## Tests
`docs/qa/T-0265-consent-preflight.md`: paired Android/iPhone consent-region debug matrices (required/not required), allow/deny, ATT never shown before configured slot, UMP-before-ATT, no predecision SDK requests, re-open privacy form, retry/offline/background; include timestamps, build SHA and screenshots without personal identifiers. Add exact automated adapter tests after the API preflight.

## Acceptance
Stay `blocked` until native bridge and iPhone build are proven, exact files/SDK callbacks have been pinned and owner has run native consent tests. No consent grants are presumed.

## Rollback
Select the Fake adapter only in dev/test; never silently discard a user's consent state.
