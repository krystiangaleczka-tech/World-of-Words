---
id: T-0350
title: Bind Settings privacy-policy action to explicit browser handoff
epic: E21
type: feat
area: features.settings
risk: medium
executor: sol
think: high
ui: high
status: review
depends_on: [T-0349]
touch:
  - game/features/settings/settings.gd
  - game/features/settings/policy_binding.gd*
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_policy_ui.gd*
  - docs/contracts/settings.md
  - docs/qa/T-0350/**
  - tasks/epics/E21-settings.md
  - tasks/T-0350-settings-policy.md
revision: 1
---

## Goal
Implement ROADMAP T-0288 privacy-policy presentation using T-0349. The existing
large Settings screen delegates this new opt-in action to a nonvisual feature
controller; no existing action behavior or catalog component is rewritten.

## Current state
Verified main65a9a9b: Settings configure(save), privacy_policy action intent and
rows/lifecycle exist. SettingsPolicy exposes owner_matches, snapshot, changed and
request_policy. ListRow, Caption Label and Toast exist. Settings is near the lint
file-size bound, so this action belongs in features/settings/policy_binding.gd.

## Specification
- SettingsScreen.bind_policy(service:Node)->Error requires actual SettingsPolicy
  with exact loaded live Save proof before replacing. May bind before mount or live.
  Invalid bind preserves owner; requested old owner/dispatch blocks replacement.
  Unbound legacy intent remains. Expose policy_message:Label and policy_toast:Toast.
- Nonvisual Node controller owns policy binding/lifecycle/feedback; uses existing
  row plus Caption directly below it and existing Toast. No new visual component.
  Screen owns mounted controls; free unmounted controller on predelete.
- Bound row explicitly dispatches request_policy once, no action_requested echo,
  no browser operation on binding/read/refresh/translation/entry. Requested shows
  reserved leading-slot spinner and disables duplicate commands.
- Persistent wrapped copy reports requested/handed_off/failed/unavailable or busy.
  Handoff means only request passed to browser, never page loaded/consent granted.
  Generic failure permits explicit row retry; unavailable disables until valid
  rebind. No raw URL/provider error, full install_id or other payload in UI.
- Terminal/error Toast dedupe uses owner/revision/attempt, marked only on successful
  show. New attempts hide old Toast; hide/detached completion appears once on return.
  Translation/theme refresh cannot replay/dispatch. Errors scoped to snapshot
  revision so a newer authoritative result supersedes stale command rejection.
- Exit disconnects; retained entry/every refresh revalidates owner, reconnecting once.
  Loss of service/port/Save (including before first mount or during detached entry)
  terminates as unavailable without recursion, no legacy fallback; Back remains
  usable. PL/EN live copy. No Save or existing service/action behavior changes.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1: Existing catalog only; no visual component created.
R-UI-2: New component requires separate task; none introduced.
R-UI-3: Existing tokens/themes only.
R-UI-4: PL/EN keys, no plural-dependent copy.
R-UI-5: Never edit generated themes.
R-UI-6: Native three-class PL/PSEUDO default100/HC130 evidence required.
Reference docs/DESIGN.md#settings and FR-SET-03.

## Tests
Actual Save/SettingsPolicy and controlled browser: invalid/foreign/unconfigured/
legacy; before/live bind with no auto-open; one committed-language handoff; pending
and terminal reentry; error/retry/Back; hidden/detached completion/dedupe; service/
port loss and explicit rebind; freed Save before mount and retained entry; live
copy/theme/keyboard and unchanged Save. Native12-case geometry +36 ready/handed_off/
failed PNGs via WOW_SETTINGS_POLICY_CAPTURE_DIR. Full check, fresh review and all
exact-head CI including Android.

## Out of scope
Real policy URL/native transport/encoding/device/legal approval, boot/global Nav,
new analytics/schema, existing restore/privacy/support/licences behavior.

## Rollback
Squash revert removes additive opt-in binding and copy; no persisted changes.
