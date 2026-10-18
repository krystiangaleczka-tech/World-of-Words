---
id: T-0343
title: Expose explicit provider privacy options requirement
epic: E21
type: contract
area: platform.consent
risk: high
executor: sol
think: med
ui: none
status: review
depends_on: [T-0262, T-0342]
touch:
  - game/platform/consent/consent_adapter.gd
  - game/platform/consent/consent_fake.gd
  - game/tests/unit/platform/test_privacy_requirement.gd*
  - docs/contracts/monetization.md
  - tasks/epics/E21-settings.md
  - tasks/T-0343-privacy-requirement.md
revision: 1
---

## Goal
Prepare ROADMAP T-0288 Privacy Options through a bounded Phase-2 rolling-wave
contract split. Give its future service/UI an authoritative provider requirement;
UMP consent and ATT states must not be mistaken for that independent requirement.

## Context
- docs/PRODUCT.md#fr-consent-privacy-consent (FR-CONSENT-03): "Settings contains a Privacy options entry that reopens
  the UMP privacy options form when required."
- docs/contracts/monetization.md#independent-privacy-options-requirement-t-0343: "ConsentAdapter.analytics_resolved(bool) carries a
  purpose-specific, legally/provider verified decision."
- Existing provider operations and their token/terminal suppression stay unchanged.

## Current state
Preflight on main d46a9bf: ConsentAdapter extends RefCounted, State and AttStatus,
consent_resolved/att_resolved/analytics_resolved/operation_failed and
show_privacy_options()->void exist. ConsentFake owns manual/controlled outcomes,
operation_token(), settle(token), resolve_analytics(token,allowed) and reset().
No privacy requirement getter or notification exists. No real provider is active.

## Specification
- Add ConsentAdapter.PrivacyRequirement enum UNKNOWN, NOT_REQUIRED, REQUIRED;
  privacy_options_requirement()->PrivacyRequirement returns UNKNOWN by default;
  privacy_options_requirement_changed(requirement:PrivacyRequirement) notifies
  actual provider changes. Native implementations must update getter before emit,
  report UNKNOWN when authoritative evidence is unavailable, and emit only changes.
- Requirement is independent of State, ATT, analytics permission and command/form
  acceptance. UNKNOWN never authorizes visibility/opening. No provider call on read.
- ConsentFake overrides the getter and adds
  set_privacy_options_requirement(requirement:int)->Error. Only closed enum values
  accepted; invalid input changes nothing, including pending token/outcome/call log.
  Publish a changed value before synchronous notification; duplicates emit nothing.
- Setter is explicit provider control: never starts/completes/cancels a consent/ATT
  operation or emits consent/ATT/analytics/failure. Valid updates preserve pending
  operation tokens and explicit analytics decision capability.
- reset() cancels pending tokens and clears existing controls/logs as before,
  restores UNKNOWN and emits one requirement notification only if it changed.
  Changes are instance-local; reentrant observers may synchronously read the value.

## Out of scope
Monetization state machine, Settings binding/visibility, SDK/boot activation,
provider mapping/certification, platform permissions/endpoints, new telemetry or
Save data. Follow-up service contract and UI binding remain necessary for T-0288.

## Tests
New test_privacy_requirement.gd covers base/Fake UNKNOWN and zero provider calls;
all transitions/deduplication/read-before-notify; invalid values with an in-flight
operation; all UMP and ATT outcomes independent of requirement; requirement never
implies analytics; explicit update preserving pending settlement and analytics;
reset clearing old tokens/controls and notification dedupe; separate instances.
Existing Fake and Monetization tests must remain green without modification.

## Acceptance
Full make check, independent fresh review and exact-head CI pass. No native UI
capture required: there is no UI or generated-theme change.

## Rollback
Squash revert removes the additive unactivated contract, without persisted changes.
