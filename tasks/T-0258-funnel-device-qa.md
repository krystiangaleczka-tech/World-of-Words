---
id: T-0258
title: Configure Firebase funnels and verify event delivery on devices
epic: E25
type: test
area: data.analytics
risk: low
executor: human
think: none
ui: none
status: blocked
depends_on: [T-0253, T-0328]
touch:
  - tasks/T-0258-funnel-device-qa.md
  - docs/qa/T-0258-funnel-plan.md
  - docs/qa/T-0258-device-evidence.csv
revision: 1
---

## Goal
Create production-meaningful funnel explorations F1–F3 in the selected
Firebase/GA4 project and verify real telemetry delivery on Android and iOS
without violating analytics consent.

## Context
- docs/PRODUCT.md#funnels — canonical F1, F2, F3 event sequences.
- docs/PRODUCT.md#fr-anl-analytics — bounded and consent-gated telemetry.
- docs/decisions/0009-platform-providers.md — Firebase Analytics selected,
  native integration and device proof remain outstanding.
- docs/TESTING.md#reference-devices — Galaxy A15 and iPhone 13 Pro Max.
- docs/qa/T-0258-funnel-plan.md — provider and device QA execution packet.

## Current state
- Event names and types exist in game/data/analytics/*.json.
- T-0250 consent-gated analytics queue exists; T-0251 listener is an open draft PR.
- Real provider dashboard QA cannot be established using Godot Fakes.
- Required T-0253 real crash adapter and T-0328 P2b listener are not merged.
- No authorized GA4/Firebase project session or physical device test
  evidence has been provided for this task.

## Specification
1. Configure the exact F1–F3 steps and exclusions documented in the QA plan.
2. Verify F1 slot filters for app integer event parameters in the provider.
   If the provider cannot filter them, escalate instead of changing schemas.
3. Run positive/negative consent, offline replay, hint and sandbox purchase
   cases on actual Android and iOS builds with valid SDK integration.
4. Record the results, build SHA, redacted evidence references and blockers
   in docs/qa/T-0258-device-evidence.csv; do not record personal data.
5. Keep task blocked until dependencies, saved dashboard funnels, device
   evidence and owner acceptance exist.

## Out of scope
- Creating Firebase accounts or changing analytics schema and SDK.
- Altering UMP/ATT behavior or live IAP entitlement rules.
- Substituting editor/GUT Fake tests for provider/physical-device validation.

## Tests
File: docs/qa/T-0258-device-evidence.csv
- F1 onboarding event payloads and exact ordered steps.
- F1 D1 return must be a true day-1 cohort, not a same-day app relaunch.
- F2 direct/rewarded conversion and no-fill/early-close false positives.
- F3 sandbox purchase, cancelled/deferred and no duplicate grant.
- Unknown/allowed/denied/revoked consent, offline queue and reconnection.
- Run on both reference OS families and validate DebugView/report artifacts.

## Acceptance
- F1–F3 are saved and evidenced in the authorized provider dashboard.
- All required Android/iOS QA scenarios pass, with reviewed evidence.
- Privacy restrictions are met and Chris marks final acceptance.

## Escalation
S1: T-0253 and T-0328 prerequisites are not merged. The owner has explicitly
requested progressing through numbered tasks; this PR prepares only
documentation, not misleading simulated device/provider evidence.
S11: Provider accounts/permissions and sandbox identifiers are human-controlled.
No credentials, live SDK setup or dashboard changes are attempted here.
