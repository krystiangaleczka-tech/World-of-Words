---
id: T-0217
title: Add cards option rows and content state panels
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0216]
touch:
  - game/ui/components/CatalogAction.gd*
  - game/ui/components/Card.gd*
  - game/ui/components/Card.tscn
  - game/ui/components/card_media.gdshader*
  - game/ui/components/ListRow.gd*
  - game/ui/components/ListRow.tscn
  - game/ui/components/StatePanel.gd*
  - game/ui/components/StatePanel.tscn
  - game/ui/gallery/content.gd*
  - game/ui/gallery/content.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/gallery.csv
  - game/tests/integration/test_card_row_state.gd*
  - docs/qa/T-0217-card-row-state.md
  - tasks/T-0217-card-row-state.md
revision: 1
---

## Goal
Provide reusable grouped content, native option rows and explanatory empty/error states.

## Context
DESIGN.md#card, #listrow, #statepanel-addition. SURFACE/Radius.M/Elevation.LOW;
ListRow minimum Touch.MIN_TARGET with Body/Caption and STROKE divider.

## Current state
Fresh main bed7489 contains T-0216 and347 GUT tests. ActionButton native intent/states,
CatalogSurface passive labels/icons/panel styling, Badge, PrimaryButton and LocaleCatalog exist.
Card/ListRow/StatePanel do not exist. Owner authorizes serial technical handoff while device gates
remain open. No feature screens are wired in this task.

## Specification
1. Internal CatalogAction extends ActionButton; native pressed/focus/disabled states remain intact.
   Passive wrapped title/subtitle content replaces native text. Token margins and content-derived
   minimum height support locale/theme growth. Native action motion/reduction inherited; translations
   independently registered/released and signals disconnected on exit/re-entry.
2. Card extends CatalogAction: inherited text_key/sublabel_key, title_key alias, media:Texture2D?,
   action_key:String optional owned PrimaryButton emitting action_requested. tappable:bool=false,
   locked:bool=false and locked_label_key:String. Passive cards suppress native pressed/focus;
   explicit tappable enables card intent. Native disabled and locked suppress both intents; locked
   shows lock Badge plus translated label, hides body and desaturates media via local shader.
   highlighted preserves outline. SURFACE/Radius.M/LOW; content scroll is screen-owned.
3. Card.configure_body(content:Control)->Error accepts detached passive content only: reject null,
   self/ancestor, foreign parent, focusable or interactive descendants atomically (all body Controls must ignore mouse input;
   text inputs/buttons/ranges rejected even with focus disabled). Detach old content
   without freeing; caller owns lifetime. Exit detaches, re-entry remounts; caller freeing tolerated.
4. ListRow extends CatalogAction: title_key alias, subtitle_key alias, leading_icon:Texture2D?,
   trailing_kind:none|chevron|value|toggle|slider and trailing_value:String dynamic numeric/value.
   configure_trailing(control:Control,kind:StringName)->Error takes caller-owned detached BaseButton
   for toggle or Slider for slider, atomically rejects invalid/self/foreign. Other variants remove old
   control without freeing. Whole row native pressed, minimum144; child input consumes its own event
   so intent is never doubled. Disabled/loading row suppresses child input, restoring its prior native
   availability on re-enable/detach; locale/theme/wrap/re-entry/resize preserve caller ownership.
   STROKE divider, existing arrow-left rotated for forward cue. Actual Toggle/Slider arrive T-0218.
5. StatePanel extends PanelContainer: configure(kind,title_key,body_key,action_key="")->Error,
   accepts offline|error|empty|unavailable with nonempty title/body atomically. Passive official
   variant icon plus wrapped Subtitle/Body and optional owned PrimaryButton emits action_requested;
   one action maximum, no automatic retry/service calls. Own copy/theme survives locale/re-entry.
6. Content gallery scrolls Card normal/pressed/disabled/locked/highlighted, all ListRow variants
   including native prototype toggle/slider, four StatePanel kinds with/without action. No project,
   theme/token/service/economy/content/save/export changes. Native review matrix and startup smoke.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1/2 catalog components only; R-UI-3 token/theme visuals/motion; R-UI-4 static copy via locale;
R-UI-5 generated themes untouched; R-UI-6 native3classes xPL/PSEUDO xdefault100/HC130 evidence.
Physical device/screen-reader/taste/Opus gates remain open.

## Tests
- Card native passive/tappable/disabled/locked/action signals and focus, lock cue/desaturation,
  highlighted/reduced motion, atomic body ownership/free/re-entry and translated wrapping/theme.
- Row native whole-row/child input without double intent, disabled child restoration, all variants,
  invalid config atomic, ownership/re-entry/minimum144 and locale/theme/divider.
- StatePanel four kinds and atomic invalid config, optional single action native intent, passive
  content and owned translations; Content gallery inventory and scroll/wrap atHC130/PSEUDO.
- Existing assertions unchanged, full make check, scope/task lint, independent fresh review and
  final-head13 CI controls before merge and beginning next implementation.
