---
id: T-0342
title: Bind Settings restore purchases to authoritative results
epic: E21
type: feat
area: features.settings
risk: high
executor: sol
think: med
ui: high
status: review
depends_on: [T-0341, T-0285]
touch:
  - game/features/settings/settings.gd
  - game/services/monetization.gd
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_restore.gd*
  - docs/contracts/settings.md
  - docs/qa/T-0342/**
  - tasks/epics/E21-settings.md
  - tasks/T-0342-settings-restore.md
revision: 1
---

## Goal
Implement the restore UI portion of ROADMAP T-0288 under Phase-2 rolling-wave
planning, consuming merged T-0341 without analytics-driven logic or native claims.

## Current state
SettingsScreen.configure(save), action_requested(restore), _refresh and lifecycle
hooks exist. Unbound screen emits intent only. Monetization exposes restore_snapshot,
restore_changed, restore_purchases, retry_restore_settlement and expire_restore.
No public same-Save binding check. Toast, Caption Label, TextButton and ListRow exist.

## Specification
- Add readonly Monetization.restore_owner_matches(save:Node)->bool: true only for
  the actual loaded configured Save and bound IAP flow in a live service tree.
  SettingsScreen.bind_restore(service:Node)->Error validates exact service type
  and same Save before replacing binding. Reject invalid/foreign bindings,
  reentrant dispatch and replacement of a requested/settling service. Unbound
  legacy callers retain intent-only behavior.
- Bound Restore calls restore_purchases once, without action_requested echo.
  Requested is disabled/loading; settling is disabled WITHOUT provider spinner,
  with a TextButton calling retry_restore_settlement only. Failed/unknown can
  request a new restore via the row. Rejected commands show busy/failure feedback.
- Persistent wrapped Caption status and retry appear below Restore. Only completed
  shows unique restored count (Label: N) or verified empty result. Idle hides copy.
  Service loss fails closed as unavailable until explicit valid rebind, never
  silently falling back to another intent owner. Other controls/Back remain usable.
- Existing Toast announces new terminal result or command error, never acceptance.
  Count stays in Caption; Toast uses generic success. Dedupe by service identity,
  snapshot revision and explicit attempt, preserving refresh/reentry suppression.
  A result completed while detached/hidden appears once on return. Copy translates
  live PL/EN. Never display raw error/provider text or interpret telemetry.
- Disconnect service signals on exit, reconnect once on retained entry and resync.
  Back does not cancel service work. Service exit clears stale loading. Guard
  nested row/retry dispatch. The same-Save check is the sole service API addition;
  no IAP grant/schema/product/SDK/endpoint/permission/boot/Nav/theme changes.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1: A screen task may not create a component. Existing catalog only.
R-UI-2: New component = separate task; none introduced.
R-UI-3: Tokens/theme variations for visual values, no raw visuals.
R-UI-4: PL/EN translation keys, no plural-dependent sentences.
R-UI-5: Never edit generated themes.
R-UI-6: Native three-class PL/PSEUDO default100/HC130 screenshots required.
Reference docs/DESIGN.md#settings and FR-SET-03/FR-IAP-06.

## Tests
Real Save/Economy/Monetization with controlled store: valid/unconfigured/foreign
binding; unbound intent; requested loading/duplicates; verified empty/owned results;
failure/timeout/retry; failed-write settlement-only retry; reentry/hidden completion
and Toast dedupe; service loss/rebind; pending Back; keyboard; live translation/theme
and reentrant dispatch. Save settings never change. Native 12-case matrix checks
long feedback, retry target, TopBar fit, scroll reach/no horizontal overflow;
capture pending/completed/settling images (36 PNGs) via
WOW_SETTINGS_RESTORE_CAPTURE_DIR in native X11. Full make check, independent review,
all exact-head CI green. Global/native activation and other T-0288 actions stay open.

## Rollback
Squash revert removes binding/read-only guard/copy; no saved data change.
