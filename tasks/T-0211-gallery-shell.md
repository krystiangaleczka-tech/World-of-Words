---
id: T-0211
title: Add the runnable P2 gallery shell and preview switches
epic: E14
type: feat
area: ui.gallery
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0132, T-0203]
touch:
  - game/ui/gallery/gallery.gd*
  - game/ui/gallery/gallery.tscn
  - game/ui/gallery/samples.gd*
  - game/locale/gallery.csv*
  - game/tests/integration/test_gallery_shell.gd*
  - docs/qa/T-0211-gallery-shell.md
  - tasks/T-0211-gallery-shell.md
revision: 1
---

## Goal
Run a desktop/device gallery shell with isolated fixed-size previews, native review switches
and typography samples. Reuse existing provisional galleries; later component tasks populate
final states and T-0327 automates screenshot rendering.

## Context
- DESIGN.md#gallery-scene specifies layout/language/contrast/text-size/motion/insets switches.
- ROADMAP T-0211 is the shell task, not implementation of future components or motion rows.
- Pinned T-0207/T-0208 themes and T-0210 guards are reviewed technical inputs.

## Current state
- Fresh main ab67ff0 fast-forwarded to reviewed T-0210 ed06674 (13/13 CI PASS); stacked draft.
- ui/gallery contains controls, wheel, board and debug_components scenes; no gallery.tscn shell.
- ScreenScaffold.debug_insets and apply_insets support fake viewport-space safe areas.
- LocaleCatalog.register_all/unregister owns duplicate translations; Tokens.reduced_motion exists.
- Six themes expose Palette colours and Label type variations. Provisional components still
  override some default palette/text sizes; final HC/text-scale states are subsequent tasks.
- Android release already excludes ui/gallery/*; no export/project setting changes needed.

## Specification
1. Create gallery.tscn and typed GalleryShell Control. A SubViewport holds one preview scene
   at exact COMPACT1080x1920 / REGULAR1080x2340 / TABLET1440x1920. Scale only its display to fit
   available shell space; preserve preview coordinates and usable input. Resize updates fit.
2. Native tool controls select layout, PL/EN/PSEUDO, text100/115/130, HC, reduced motion,
   fake insets and Samples/Controls/Wheel/Board/Debug pages. These are gallery tooling,
   not new product widgets. All labels use gallery locale keys.
3. Generated theme applies to the preview root. Samples use theme type variations/Palette.
   Shell explicitly labels provisional galleries; do not claim their hardcoded overrides
   support final HC/text scaling. Rebuild previews on changes, freeing old scene cleanly.
4. Register owned locale copies. PL/EN use actual translations. PSEUDO uses EN with native
   pseudolocalization, accents and expansion ratio0.35, double-vowels off. Set runtime-only
   pseudo settings and restore prior values (including absent properties), prior locale,
   pseudo-enabled and reduced-motion flags when gallery exits. No persistent settings/save.
   One gallery shell per process; no new autoload/global ownership mechanism.
5. Fake insets use Tokens.Space.M left/right and Space.L top/bottom, applied to scaffold
   after preview layout settles. No real device safe area leaks into subviewport previews.
6. Samples page includes PL pangram/restore copy, EN baseline, numeric0/9 999/99 999 using
   Numeric font, eight-letter wheel and max-sized grid based on LevelData.MAX_GRID. Use
   a labelled synthetic sparse geometry fixture without editing content or solving a level.
   DE samples and full state/motion catalog remain later-phase work.
7. Expose configure(layout:StringName,language:StringName,high_contrast:bool,text_percent:int,
   reduced:bool,insets:bool,page:StringName=&"Samples")->Error, preview_viewport()->SubViewport,
   preview_screen()->ScreenScaffold. Invalid input returns ERR_INVALID_PARAMETER atomically.
   Callable before ready; defaults REGULAR/PL/default100/motion on/insets off/Samples.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1/R-UI-2: reuse catalog scenes; no product component created by shell task.
- R-UI-3: styling/spacing/motion uses Tokens or theme; exact gallery device fixture sizes
  and pseudo ratio are specified above, not game balance values.
- R-UI-4: visible copy uses locale keys; no plural-dependent sentences.
- R-UI-5: no generated-theme edits.
- R-UI-6: capture COMPACT/REGULAR/TABLET in PL/PSEUDO, including HC130; no device acceptance claim.

## Tests
- test_gallery_shell.gd: default exact viewport/theme/samples; all switch combinations select
  exact geometry/theme/locale/pseudo flags and insets; invalid configuration preserves state;
  changing pages frees old previews without duplicate screen nodes; resize scales presentation
  only; exit restores prior locale/pseudo settings/reduced motion and releases owned translations.
- Samples expose named Labels for pangram/restore/numeric samples, eight tile identities and
  MAX_GRID geometry. No production service/save/economy calls.
- make check, task/scope lint, fresh review, final-head CI. Native screenshot matrix visually
  checked; release resource inspection retains existing gallery exclusion.

## Out of scope
Final component styling/states, full motion gallery, DE, CI screenshot job, game navigation,
phone install, theme/token changes, project/export changes, persistence or ROADMAP edits.

## Escalation log
2026-10-12: owner next-task handoff authorizes bounded gallery tooling on reviewed pinned
technical parents. Original human taste/device/Opus gates remain open. All-components/all-motion
DESIGN target is populated by subsequent component tasks; this implements the ROADMAP shell.
