---
id: T-0348
title: Route Settings to caller-owned offline licences and back
epic: E21
type: feat
area: features.settings
risk: medium
executor: sol
think: high
ui: high
status: review
depends_on: [T-0347, T-0340]
touch:
  - game/features/settings/licences_route.gd*
  - game/tests/integration/test_licences_route.gd*
  - docs/contracts/settings.md
  - docs/qa/T-0348/**
  - tasks/epics/E21-settings.md
  - tasks/T-0348-licences-route.md
revision: 1
---

## Goal
Close the explicit offline licences caller portion of ROADMAP T-0288 in the next
Phase-2 rolling wave. T-0349 adds browser handoff ownership; T-0350 binds policy UI.
No global Nav/provider activation or destination setup is included in this wave.

## Current state
Verified main c48da1d: SettingsScreen action_requested(licences), rows, scroll,
text_sheet/language_sheet exist; LicencesScreen has select_notice, selected_id,
scroll, rows, back_requested and two-stage handle_back. Existing route is only a
test lambda, not reusable production composition. Scenes are caller-owned siblings.

## Specification
- New licences_route.gd extends Node, no visual component or singleton.
  configure(settings:Node,licences:Node)->Error requires actual ready live screen
  types, same parent and viewport, nonempty Settings snapshot, visible Settings and
  hidden Licences. Invalid replacement preserves old route; active/dispatch returns
  ERR_BUSY. Configuration connects once but never opens/hides/resets either screen.
- open()->Error requires valid connected ownership and visible Settings/hidden
  licences; active duplicate is rejected. Reject while either Settings Sheet is not
  closed. On explicit licences intent/open hide Settings and show existing Licences,
  preserving Settings scroll/focus and retained legal selection/data. No Save write.
- Active licences adopts Settings theme; live Settings theme change follows only
  while active. Restore caller's previous licences theme on return/invalidation.
- handle_back()->bool delegates to existing licences two-stage Back only while
  active; detail -> index, index -> Settings. Otherwise false. TopBar back works too.
  Returning restores Settings scroll and previous valid focus (fallback licences row)
  deferred, without stealing focus if a new visit/hidden owner supersedes it.
- Guard synchronous visibility callback reentry. Other Settings intents unchanged.
  Exit/loss/reparent/free disconnects and invalidates; hide orphan licences and
  restore Settings if this route was active. Explicit configure needed after loss;
  retained router exit/reentry must not reconnect silently or duplicate listeners.
  snapshot()->Dictionary reports bound/state (settings/licences/unavailable).

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1: Existing catalog only; no visual component created.
R-UI-2: New component needs separate task; none introduced.
R-UI-3: Existing tokens/themes only.
R-UI-4: Existing PL/EN keys, untranslated legal text preserved.
R-UI-5: Never edit generated themes.
R-UI-6: Native three-class PL/PSEUDO default100/HC130 evidence required.
Reference docs/DESIGN.md#settings and FR-SET-03.

## Tests
Actual scenes/Save: invalid/default binding, intent/open and duplicate guard,
two-stage Back with scroll/focus restoration, Sheet blocking, synchronous reentry,
other intents and Save unchanged, live theme/locale with verbatim legal data,
owner/router exit/reentry/reconfigure and no duplicate listeners; profile loss in
both visibility transitions and reconfigure before deferred focus restoration. Native12-case
geometry +36 index/detail/returned PNGs via WOW_LICENCES_ROUTE_CAPTURE_DIR.
Full make check, fresh independent review and exact-head CI including Android.

## Rollback
Squash revert removes opt-in routing; no saved data or existing screen change.
