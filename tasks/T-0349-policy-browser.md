---
id: T-0349
title: Own explicit privacy-policy browser handoff
epic: E21
type: contract
area: features.settings
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0348]
touch:
  - game/services/settings_policy.gd*
  - game/tests/integration/test_settings_policy.gd*
  - docs/contracts/settings.md
  - tasks/epics/E21-settings.md
  - tasks/T-0349-policy-browser.md
revision: 1
---

## Goal
Prepare ROADMAP T-0288 privacy-policy action before T-0350 Settings binding. The
caller owns an approved localized HTTPS destination/native browser port; this task
supplies no endpoint and invokes no real browser or network.

## Context
- docs/DESIGN.md#settings: Privacy policy opens browser.
- docs/PRODUCT.md#non-functional-requirements: NFR-10 data minimization.
- Existing support handoff distinguishes command acceptance from delivery; policy
  handoff likewise cannot certify loaded content or legal approval.

## Current state
Verified main3313d45: Save.is_loaded/committed_view exposes settings.language.
Settings emits privacy_policy intent. Caller-owned settings_support.gd provides
explicit validated port pattern; there is no policy owner, configured URL or browser.

## Specification
- New settings_policy.gd extends Node, unactivated/caller-owned, no autoload.
  configure(save:Node,browser:Callable)->Error validates actual loaded Save and
  valid one-argument port before replacing. Invalid input preserves existing bind.
  Port(language:String)->Error is synchronous; caller resolves an approved localized
  HTTPS URL and maps native handoff errors. No identity/Save contents/URL supplied
  by the screen; no destination/provider/permission implementation in this task.
- owner_matches(save:Node)->bool requires exact loaded Save, live configured Node
  and valid browser. Exit invalidates until explicit configure, including reentry.
- snapshot()->Dictionary returns fresh available:bool,state:StringName,error:Error,
  revision:int. States idle/requested/handed_off/failed; invalid binding unavailable.
  No UI strings or locale registration needed for this data-only observation.
- request_policy()->Error snapshots committed content language before requested
  notification, dispatches exactly once to browser and records handed_off/OK or
  failed/actual Error. OK is accepted browser handoff, never document loaded or
  consent granted. No auto-open/retry on binding/read/locale/entry/refresh.
- changed increments instance revision. Notification/dispatch blocks configure and
  nested request with ERR_BUSY, preserving results. Owner/port loss before dispatch
  suppresses call; loss during call cannot claim handoff. Internal liveness checks
  must be safe for freed Save. Invalid return type/Error value -> ERR_INVALID_DATA.
- No Save mutation, install_id/receipts/wallet/analytics, persisted history, HTTP
  fetch or interpretation of arbitrary URLs. Explicit retry is a new request.

## Tests
Actual Save + controlled browser: defaults/live owner/invalid binds/arity; fresh
snapshots; no config/read/locale calls; only committed language delivered (UI EN
preview does not change PL); unchanged Save and no identifiers; valid/invalid port
returns and explicit retry; requested/terminal/dispatch reentry; owner/port loss
before dispatch/during callback; freed Save reads; retained exit/reconfigure.
Full make check, independent fresh review and exact-head CI including Android.

## Rollback
Squash revert removes additive unactivated owner; no persistent state.
