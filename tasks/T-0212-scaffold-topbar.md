---
id: T-0212
title: Finalize safe-area scaffold and add the TopBar catalog component
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: med
ui: high
status: review
depends_on: [T-0132, T-0203]
touch:
  - game/ui/components/ScreenScaffold.gd
  - game/ui/components/TopBar.gd*
  - game/ui/components/TopBar.tscn
  - game/ui/gallery/scaffold.gd*
  - game/ui/gallery/scaffold.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/gallery.csv
  - game/tests/integration/test_scaffold_topbar.gd*
  - docs/qa/T-0212-scaffold-topbar.md
  - tasks/T-0212-scaffold-topbar.md
revision: 1
---

## Goal
Provide final safe-area/container behavior and a reusable TopBar, retaining current P1
screens' public body/path contract. Add a gallery entry; production header integration
and final action widgets remain later tasks.

## Context
- DESIGN.md#screenscaffold-and-safe-areas, #layout-classes, #screenscaffold, #topbar.
- TABLET content caps at Layout.MAX_CONTENT_WIDTH and centres inside the safe rectangle.
- Reference: owner-selected Ceramic T-0204/T-0205 mockup headers; pinned reviewed tokens/themes.

## Current state
- Fresh main ab67ff0 fast-forwarded to reviewed T-0211 5dfc5ca (13/13 CI after one engine-import retry).
  Stacked draft; merge parents first. Human taste/device/Opus gates remain open.
- ScreenScaffold.gd exposes body:VBoxContainer, layout_class, layout_class_changed, debug_insets,
  apply_insets(Rect2,Vector2)->void. Safe/Body and first background ColorRect are used by current
  tests/gallery; preserve those paths/order. It listens to own resized, not viewport.size_changed.
- Current margins are Space.M plus injected insets; no TABLET width cap or optional chrome/art.
- No TopBar exists. Generated themes expose Palette and Subtitle variation; icon assets exist.
- GalleryShell.PAGES can add a scene without changing production navigation/export settings.

## Specification
1. Keep existing ScreenScaffold body/path/signature/signal compatibility. Add optional
   top_bar:TopBar, bottom:Control and background:Texture2D properties. Backdrop and cover art
   fill the root; background uses current theme Palette.BG. Chrome is owned by public Body
   stack: header first, footer last, consumer content between them; optional values default null.
   Replacing a slot detaches old controls without freeing caller-owned controls; reject controls
   already owned by another parent. No nested scaffolds. Connect/disconnect own/viewport resize
   and child-order signals; safe-area refresh is idempotent across detach/re-entry.
2. Convert screen-space safe intersection using viewport_size/window_size and window position.
   Add public static screen_insets(safe:Rect2i,window:Rect2i,viewport:Vector2)->Rect2 for deterministic
   verification. Invalid/zero window or no intersection yields zero; never divides by zero.
   SubViewport/headless runs use injected/zero insets, never desktop display bounds.
3. Clamp negative insets to zero. Classify from safe height/width before default padding at
   exact token thresholds; invalid/nonpositive usable dimensions preserve previous class.
   Ceil inset margins to keep fractional edges safe. TABLET caps body width at MAX_CONTENT_WIDTH
   after Space.M padding, splitting additional margins to centre within usable safe rectangle.
   Own/viewport resize recomputes; emit class signal only when actual class changes.
4. Add TopBar Control scene/script with leading:Array[Control], title_key:String, trailing:Array[Control]
   properties and configure(leading_controls:Array[Control],key:String,trailing_controls:Array[Control])->Error.
   Optional transparent:bool=true (Level); false uses current theme Palette.SURFACE.
   Validate atomically: max3 per side, unique controls, not inside another owner, no text buttons.
   Existing IconButton/HintButton are allowed provisional action types; reject TextButton and
   generic text Buttons. Labels/other passive controls allowed. Slots detach without freeing.
5. TopBar reserves fixed Layout.TOP_BAR_H and Space.S gaps. Title uses translated Subtitle,
   wraps if necessary rather than clipping; equal side lanes keep title centred despite
   asymmetric content. Slot lanes never overlap; if natural lane widths/title minimum cannot fit, expose
   fits:bool=false (fits_changed(value:bool) emits only on change) and hide title while retaining slots (gallery flags the unsupported case).
   On an unsupported viewport narrower than both lanes, slots remain enabled/visible but
   may extend beyond the bar. The gallery flags fits=false; consumers must use fitting
   configurations. Do not promise oversized future widgets fit a phone.
   Translation ownership is independent; refresh locale/theme and disable double auto translation
   on explicitly translated title. Disconnect manually connected signals on exit.
6. Gallery Scaffold page shows labelled header/body/footer, asymmetric slots and PL/EN title;
   use passive native labels/official icon textures until final IconButton T-0214. Demo art
   uses generated local GradientTexture2D with Palette colours, no dependency/source asset.
   Existing Samples paths stay intact; no production screen header is newly mounted.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1/R-UI-2: this is the dedicated component task plus gallery entry; no product screen widget.
- R-UI-3: all visuals/motion use Tokens/current theme. R-UI-4: all copy uses locale keys.
- R-UI-5: generated theme untouched. R-UI-6: inspect COMPACT/REGULAR/TABLET ×PL/PSEUDO, default
  and HC130 screenshots with fake insets. Device screenshots/taste approval remain a human gate.

## Tests
- test_scaffold_topbar.gd: deterministic screen→viewport conversion/window offset/invalid windows;
  exact aspect boundaries, signal deduplication/invalid dimensions, fractional/clamped insets,
  TABLET cap/centre with asymmetric safe insets, background theme/cover art and optional chrome
  ordering/replacement/ownership, root/viewport resize and detach/re-entry.
- TopBar max3/duplicate/foreign/text-button rejection is atomic; asymmetric lanes/title do not
  overlap, narrow case flags fits=false while all slots remain visible; subtitle/locale/pseudo/
  theme/transparent behavior; independently owned translation releases safely.
- Preserve all existing tests unchanged; make check, task/scope lint, fresh review, final-head CI.
- Gallery screenshots plus existing game startup smoke; do not claim human device acceptance.

## Out of scope
Production header integration, final icon buttons/currency components, new theme/token rules,
project/export/platform settings, save/economy, content, permissions/signing and ROADMAP edits.

## Escalation log
2026-10-12: owner next-task handoff authorizes bounded components on reviewed pinned parents.
Explicitly specified additive component APIs and scaffold internal layout changes above;
existing public body paths and null-chrome behavior are retained. Physical-device/taste/Opus
acceptance and T-0205 iPad/art gates are not closed by executor screenshots.
