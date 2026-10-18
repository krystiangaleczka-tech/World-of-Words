---
id: T-0347
title: Bind Settings support action to explicit draft handoff
epic: E21
type: feat
area: features.settings
risk: medium
executor: sol
think: high
ui: high
status: review
depends_on: [T-0346]
touch:
  - game/features/settings/settings.gd
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_support_ui.gd*
  - docs/contracts/settings.md
  - docs/qa/T-0347/**
  - tasks/epics/E21-settings.md
  - tasks/T-0347-settings-support.md
revision: 1
---

## Goal
Complete the explicit support binding portion of ROADMAP T-0288 using T-0346.
The player requests an editable draft; handoff is never reported as message sent.

## Current state
Verified main 60aa894: Settings configure(save), support intent/short ID row,
restore/privacy binding/lifecycle and Caption/Toast exist. Caller-owned
services/settings_support.gd exposes configure, owner_matches, snapshot, changed,
request_draft with readonly full committed identity and explicit composer port.

## Specification
- bind_support(service:Node)->Error requires actual SettingsSupport script and
  live exact loaded Save proof; invalid replacement preserves owner, requested old
  owner/reentrant dispatch prevents replacement. Unbound legacy intent is unchanged.
- Bound row dispatches request_draft once with no action_requested echo. Never
  opens on bind/read/locale refresh, retries automatically or sends mail.
- Requested is loading/disabled with reserved existing leading slot. Show a wrapped
  Caption below row for requested/handed_off/failed/unavailable or busy rejection.
  Handoff copy asks player to finish in mail app and never claims sent/delivered.
  Failure/unavailable copy is generic; no raw provider/error text. Only short ID
  stays visible in the row; full UUID goes solely through the explicit draft port.
- New explicit row press may retry failure/handoff; unavailable disables until
  explicit valid rebind. Rejected command errors are scoped to snapshot revision.
- Terminal/command-error Toast is deduplicated by owner/revision/attempt and marked
  seen only after successful display. New attempts hide old feedback. Hide/reentry
  terminal appears once; translation/theme refresh does not replay. PL/EN live copy.
- Disconnect on exit; validate/reconnect once on retained entry/every refresh.
  Owner/port loss fails closed until explicit rebind, with no legacy intent fallback.
  Back remains usable. No Save/settings mutation or service behavior change.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1: Existing catalog only; screen creates no component.
R-UI-2: New component requires separate task; none introduced.
R-UI-3: Tokens/theme variations only.
R-UI-4: PL/EN keys; no plural-dependent sentences.
R-UI-5: Never edit generated themes.
R-UI-6: Native three-class PL/PSEUDO default100/HC130 evidence required.
Reference docs/DESIGN.md#settings, FR-SET-03 and NFR-10.

## Tests
Actual Save/SettingsSupport and controlled composer: binding/invalid/foreign/
legacy; exact full-ID handoff and short row ID; requested duplicate/reentry guards;
error/retry/Back; hidden/detached handoff and Toast dedupe; owner/port loss including
retained owner exit while screen detached and explicit rebind; live translation/
keyboard; freed Save on retained entry terminates loss with unavailable/disabled
Support, no composer/intent and usable Back; no Save mutation. Native twelve-case geometry with 36 ready/handed_off/
failed PNGs via WOW_SETTINGS_SUPPORT_CAPTURE_DIR. Full make check, fresh review,
all exact-head CI including Android.

## Out of scope
Real address/transport/native mail/URI encoding/device verification, boot/Nav,
browser/privacy policy, sending or persisted support history/analytics.

## Rollback
Squash revert removes additive binding/copy; no persistent data changes.
