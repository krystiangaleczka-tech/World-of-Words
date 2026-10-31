---
id: T-0267
title: Certify advertising and consent behavior on Android and iPhone
epic: E18
type: test
area: platform.ads
risk: high
executor: human
think: none
ui: low
status: blocked
depends_on: [T-0266]
touch:
  - docs/qa/T-0267-ads-consent-devices.md
  - tasks/T-0267-ads-consent-device-qa.md
revision: 1
---

## Goal
Provide actual device evidence that UMP, ATT, rewarded and interstitial behavior obey product policy, without mistaking Fake/unit results for SDK certification.

## Context
TESTING.md#device-checklist ads/first-10-minutes; FR-ADS-03..08; FR-CONSENT-01/03/04; ROADMAP.md T-0267.

## Current state
T-0266 real adapter is not delivered. No two-device native consent/ad test report exists on main. Owner has the actual accounts and reference devices.

## Specification
Test release-configured **test-unit** builds on reference Android and real iPhone after T-0266 is merged. For each case record platform, OS/device, app version and commit SHA, UMP debug geography where applicable, expected result, observed result, **PASS/FAIL/BLOCKED**, evidence file/link and owner/date.
- Clean install: UMP after slot 1 (only where required), ATT after slot 6 on iPhone following UMP IDFA explainer, no SDK request before eligibility.
- Consent allow/deny and privacy-options reopen; iOS denied ATT has no personalized tracking but eligible non-personalized ad delivery can still be tested.
- Rewarded complete grants exactly once; early close, no-fill and offline grant zero, present a finite unavailable state and preserve gameplay.
- Interstitial only after eligible campaign Continue, never at launch/mid-level/daily, never before configured first slot; entitlement `nc.remove_forced_ads.v1` suppresses it while optional rewarded remains accessible.
- Background mid-ad, resume, audio pause/resume, repeat taps and stale callbacks do not freeze flow.
- Include consent rejection/retry, permission state changes and sanitized diagnostic logs.

## Tests
Manual matrix `docs/qa/T-0267-ads-consent-devices.md` with all cases on both platforms (ATT only iOS). False positives from emulators, Fakes or IDE previews do not pass the gate.

## Acceptance
Every required device row has real evidence and no unresolved failures; mark review only after Chris confirms on both platforms. Any missing device or provider state remains BLOCKED.

## Rollback
Certification is a report, not an SDK change; failed checks return T-0264..T-0266 to remediation, never edit recorded outcomes.
