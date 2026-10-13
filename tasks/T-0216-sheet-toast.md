---
id: T-0216
title: Add modal sheets and replaceable transient toasts
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0215]
touch:
  - game/ui/components/CatalogSurface.gd*
  - game/ui/components/Sheet.gd*
  - game/ui/components/Sheet.tscn
  - game/ui/components/Toast.gd*
  - game/ui/components/Toast.tscn
  - game/ui/gallery/overlays.gd*
  - game/ui/gallery/overlays.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/ui.csv
  - game/locale/gallery.csv
  - game/tests/integration/test_sheet_toast.gd*
  - docs/qa/T-0216-sheet-toast.md
  - tasks/T-0216-sheet-toast.md
revision: 1
---

## Goal
Provide caller-owned modal content with controlled dismissal/focus and readable one-at-a-time
messages. No navigation/service integration or business work occurs inside either component.

## Context
- DESIGN.md#sheet, #toast, #reduced-motion-mapping; PRODUCT.md FR-PLAT-04.
- SURFACE/SCRIM, Radius.L, Elevation.HIGH, Space.L; cap at SHEET_MAX_RATIO and scroll content.

## Current state
- Fresh mainba46675 contains merged T-0215,334 passing GUT; earlier technical parents merged.
- IconButton/ActionButton and scaffold public body/safe geometry are available; no Sheet/Toast exists.
- GalleryShell owns review locale/theme/insets and LocaleCatalog provides independent translations.
- Owner authorizes five serial tasks, including technical handoff while manual device gates stay open.

## Specification
1. Add internal CatalogSurface token-only helpers for panel style, passive labels/icons and scaffold
   bounds. No new tokens/themes/global state. Scene-tree groups scope active Sheet/Toast to viewport.
2. Sheet extends Control: title_key:String, dismissible:bool=true, busy:bool=false; read-only state
   closed|opening|open|closing and dismissed(reason:StringName). configure_content(Control)->Error
   rejects null/self/ancestor/foreign ownership atomically; old content detaches without freeing.
   New content lives in a scrolling body; exit detaches caller-owned content, re-entry remounts.
3. open()->Error: require mounted/ready; close earlier same-viewport sheet first, unless busy or
   non-dismissible (ERR_BUSY), preserving at most one visible sheet. close(force:bool=false)->bool
   blocks busy/non-dismissible unless owner forces it. Repeated transitions are idempotent and
   previous tweens are killed. Root fills owner; scrim blocks underlying GUI input.
4. Scrim tap, header downward gesture beyond Space.L, close icon and ui_cancel/native go-back all
   request dismissal; busy/non-dismissible consume Back while staying open. handle_back()->bool
   lets future Nav route Android Back before navigating. Catalog notification handling does not
   claim production Nav/device certification. Ignore secondary fingers and upward/short gestures.
5. Save/restore valid previous focus; trap native focus inside modal including external grab_focus;
   Tab/Shift-Tab cycle visible enabled descendants in visual order, with root fallback when busy.
   Connect/disconnect owned viewport/resize/GUI/input signals and register/release translations.
6. Width/height respect scaffold safe body, cap width MAX_CONTENT_WIDTH and height .85 of bounds;
   content scrolls, title wraps, bottom anchored. Resize settles interrupted transitions safely.
   Opening BASE/OUT offscreen slide+fade; closing FAST/IN; reduction before/during settles target immediately.
7. Toast extends PanelContainer, passive/no focus: show_message(key:String,variant:info|success|error,
   glyph:Texture2D=null,anchor:Control=null)->Error rejects invalid/empty key/foreign anchor atomically.
   New same-viewport message replaces old; one reusable Timer holds TOAST_HOLD milliseconds even
   under reduced motion (hold is readability, not animation). hide_message() cancels stale work.
   FAST/OUT fade+Space.S upward slide in, FAST/IN fade out; replaced tween/timer killed; own translations and signals release on exit/re-entry.
8. Toast default official info(lightbulb)/success(check)/error(x) cue, SURFACE/TEXT/MID, wrapped Body.
   Optional Level anchor places above that control; fallback below scaffold top bar. Clamp to safe
   bounds. Root/viewport resize, locale/theme refresh reposition. No buttons or currency/ads logic.
9. Overlays gallery opens normal/busy sheet with long translated content, replay/close controls,
   and three Toast variants. Native review matrix plus input/focus/scroll tests; no screen wiring.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1/2: dedicated catalog components and gallery only.
- R-UI-3: token/theme visuals and motion. R-UI-4: copy uses locale keys.
- R-UI-5: generated themes untouched. R-UI-6:3 classes xPL/PSEUDO xdefault100/HC130 captures;
  native local evidence does not close physical device/taste/Opus gates.

## Tests
- Atomic ownership/replacement/exit/re-entry, only one sheet per viewport, busy/non-dismissible replacement.
- Native scrim/close/Back/go-back/gesture dismissal exactly once; busy consumes without closing;
  multi-pointer/upward/short gestures preserved. Underlying GUI blocked.
- Focus save/trap/native Tab cycling/disabled descendants/restore, safe cap/scroll/resize, wrapping,
  locale/theme/owned translations and reduction before/during/reversed transitions.
- Toast invalid config atomic, replacement/timer lifetime including reduction, timeout/hide/exit/re-entry,
  passive descendants/default state glyphs, safe anchor/fallback placement and wrapping/locale/theme.
- Existing assertions unchanged; make check, scope/task lint, independent review, native gallery matrix,
  startup smoke and final-head CI before serial merge.

## Out of scope
Nav/gameplay/service wiring, real Android/device/screen-reader certification, platform/project/export,
save/economy/content, dependencies/tokens/themes and ROADMAP changes.
