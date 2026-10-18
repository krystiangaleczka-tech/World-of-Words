---
id: T-0345
title: Bind Settings privacy options to authoritative service state
epic: E21
type: feat
area: features.settings
risk: high
executor: sol
think: high
ui: high
status: review
depends_on: [T-0344, T-0342]
touch:
  - game/features/settings/settings.gd
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_privacy.gd*
  - docs/contracts/settings.md
  - docs/qa/T-0345/**
  - tasks/epics/E21-settings.md
  - tasks/T-0345-settings-privacy.md
revision: 1
---

## Goal
Implement ROADMAP T-0288 privacy presentation as a Phase-2 rolling-wave split,
using T-0344 results rather than telemetry or inferred consent. This wave continues
with T-0346 support draft ownership and T-0347 support UI binding after this task.

## Current state
Verified main 5e84493: Settings configure(save), action_requested, explicit privacy
availability flag, lifecycle/reentry hooks and bound restore feedback exist.
Monetization privacy_owner_matches, privacy_snapshot, privacy_changed and
request_privacy_options exist. Caption/ListRow/Toast are catalog controls.

## Specification
- bind_privacy(service:Node)->Error requires actual Monetization and exact live
  loaded Save proof. Invalid replacement preserves owner; requested old owner or
  reentrant dispatch prevents replacement. Explicit binding opts out of legacy
  privacy intent; unbound flag/intent behavior remains unchanged.
- Bound visibility uses service available only, ignoring manual availability flag.
  UNKNOWN/NOT_REQUIRED/lost owner hide row. Requested is loading/disabled with
  reserved catalog leading slot; no acceptance Toast or claim of consent granted.
- Wrapped persistent Caption below row reports requested/completed/failed/unknown/
  unavailable. Completed means privacy options closed, not consent granted.
  Failed/unknown/busy permit row retry only if provider still requires it.
  Pending status remains visible if requirement changes and row becomes hidden.
- Dispatch once, no action_requested echo. Rejected command shows translated busy
  or generic failure, scoped to snapshot revision; new results supersede stale copy.
- Existing Toast announces new terminal or command error once per service/revision/
  explicit attempt, marked seen only after successful show. Hide/reentry completion
  appears once; locale/theme refresh does not replay it. A new attempt hides old Toast.
- Disconnect on exit, validate/reconnect once on retained entry and every refresh;
  owner loss fails closed until explicit rebind, never legacy intent fallback.
  Back remains usable and never cancels service work. PL/EN live translation.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1: Existing catalog only; screen task creates no component.
R-UI-2: New component is a separate task; none introduced.
R-UI-3: Tokens/theme variations only, no raw visuals.
R-UI-4: PL/EN keys, no plural-dependent sentences.
R-UI-5: Never edit generated themes.
R-UI-6: Native three-class PL/PSEUDO default100/HC130 evidence required.
Reference docs/DESIGN.md#settings; FR-CONSENT-03.

## Tests
Real Save/Monetization + controlled ConsentFake: binding/foreign/unconfigured,
legacy intent, independent visibility, pending/duplicates/Back, terminal success/
failure/timeout and retry, busy, hidden/detached completion and dedupe, detached
owner loss/rebind, replacement/reentrant dispatch, live translation/keyboard.
Settings remain unchanged. Native 12-case geometry and 36 pending/completed/unknown
PNGs via WOW_SETTINGS_PRIVACY_CAPTURE_DIR; no headless rendering claim.
Full make check, fresh independent review and exact-head CI including Android.

## Out of scope
Boot/Nav/provider activation, real SDK/legal/device certification, analytics/schema,
provider/Save behavior, browser/mail/other actions.

## Rollback
Squash revert removes unactivated binding and copy; no persisted data change.
