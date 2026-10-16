---
id: E18
title: Consent and ads
phase: 2
status: active
---

## Goal
Resolve consent before advertising and keep every ad opt-in or policy-governed.

## Player-facing outcome
No consent at first launch; Continue sequences due legal steps and eligible ads.

## Decisions
- Explicit purpose-specific analytics result; UMP/ATT enums do not authorize telemetry.
- iOS SDK initialization waits for terminal ATT after the configured completed slot.
- Contract APIs fail closed until actual presentation/transaction owners implement them.
- T-0261 is inactive in boot; it freezes APIs and consent ordering with manual Fakes.
- Adapter operations must settle once and suppress callbacks from obsolete requests;
  real implementations must enforce this correlation before activation.

## Contracts
docs/contracts/monetization.md; frozen config keys and AdPolicy from T-0260.

## Waves
### Wave 1
- T-0260 pure interstitial/prompt policy (merged).
- T-0261 Monetization contract and consent sequencing.
- T-0262 deterministic Fake outcome controls (depends on T-0261).
- T-0263 presentation against Fakes (depends on T-0262 and T-0234).

## Open questions
None for the unactivated contract/Fake wave. Accounts, permissions and provider
purpose mappings require owner/device verification before real SDK activation.

## Exit criteria
T-0267 device ads/consent checklist passes on Android and iOS after real adapters.
