---
id: T-0346
title: Prepare readonly support drafts through an explicit composer port
epic: E21
type: contract
area: features.settings
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0345]
touch:
  - game/services/settings_support.gd*
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_support.gd*
  - docs/contracts/settings.md
  - tasks/epics/E21-settings.md
  - tasks/T-0346-support-draft.md
revision: 1
---

## Goal
Prepare the support portion of ROADMAP T-0288 with actual committed identity and
an explicit caller-owned draft composer; T-0347 binds the Settings row afterwards.
No support address or native integration is assumed.

## Context
- docs/DESIGN.md#settings: support opens mail with install_id prefilled.
- docs/PRODUCT.md#non-functional-requirements: NFR-10 random install_id and data
  minimization. No game saves, receipts, wallet, transaction keys or analytics dump.

## Current state
Verified main 521822f: Save.is_loaded()/committed_view() exposes meta.install_id and
sections.settings.language. Settings shows first eight ID characters; support
currently emits intent. There is no support composer service or configured address.
Caller-owned SettingsRuntime/SettingsLanguage are explicitly injected Nodes.

## Specification
- New unactivated services/settings_support.gd extends Node. No autoload or SDK.
- configure(save:Node,composer:Callable)->Error validates actual loaded Save and
  valid exactly-two-argument port before replacement; invalid binds preserve old.
  Port(subject:String,body:String)->Error is synchronous, opens an editable draft
  only, never sends mail; caller owns approved recipient, platform URI encoding and
  native error mapping. No real destination or implementation is introduced here.
- owner_matches(save:Node)->bool certifies live configured exact loaded Save and
  valid port. Retained exit invalidates binding until explicit configure.
- draft()->Dictionary returns fresh subject/body strings in current UI locale:
  translated subject/instruction, full committed install_id once, current app
  version and committed content language, with blank space for the player to edit.
  No writes/provider calls/other save fields. Invalid owner returns empty.
  Own an existing LocaleCatalog registration through binding/tree exit; no locale
  selection or project translation setting changes.
- snapshot()->Dictionary exposes available:bool,state:StringName,error:Error,
  revision:int,short_id:String; fresh result with eight-character display ID.
  States idle/requested/handed_off/failed; unavailable when binding invalid.
  handed_off means port returned OK, never message sent or delivered.
- request_draft()->Error snapshots exact text, publishes requested before invoking
  port once, then handed_off/OK or failed/actual Error. Rejected/unconfigured calls
  never dispatch. Invalid result type/out-of-range Error is ERR_INVALID_DATA.
  A new explicit attempt may retry after failure or handoff; no automatic retry.
- changed reports increasing instance revisions; configure/request reject callback
  reentry during notifications and dispatch with ERR_BUSY. Invalidated owner/port
  during requested notification suppresses dispatch; loss during port call cannot
  claim handoff. Successful configuration performs no provider work.

## Tests
New test_settings_support.gd with actual Save and controlled composer: invalid/
foreign/read copies, zero configure/read calls, full exact UUID (not short ID),
only closed draft data, live PL/EN and committed language, successful handoff vs
failure/invalid result/retry, requested/terminal/dispatch reentry, owner/port loss
before dispatch or during callback, retained exit/explicit reconfigure. Save unchanged.
Full make check, fresh independent review and all exact-head CI including Android.

## Out of scope
Settings UI, real mail/browser transport/recipient/endpoint/permissions, boot/Nav,
sending messages, persisted support history or analytics events.

## Rollback
Squash revert removes additive unactivated service; no persistent changes.
