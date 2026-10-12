# T-0212 safe-area scaffold and TopBar

ScreenScaffold retains `Safe/Body`, public Body, apply_insets and class signal signatures.
The first child remains its theme-coloured backdrop for the existing gallery contract.
Optional cover art bleeds across the root; content gets ceiled safe edges plus Space.M.
TABLET adds equal centre margins (with an integer rounding split) to cap the content
column at MAX_CONTENT_WIDTH. Classification uses safe dimensions before body padding,
with exact TABLET/COMPACT token boundaries. Zero/invalid usable geometry preserves class.
Screen-pixel/window-offset conversion is exposed as a deterministic static method.
SubViewport/headless runs use explicit/zero insets, without reading desktop display bounds.

Optional top_bar and bottom controls live at the first/last positions of the existing
Body stack, with composing-screen content between them. Slot replacements detach caller
controls without freeing them. Foreign parents and duplicate chrome slots are rejected.
Own/viewport resizing and child-order signals reconnect across re-entry and disconnect on exit.

TopBar reserves TOP_BAR_H, a Subtitle title and equal-width side lanes, with Space.S gaps.
It validates an entire configuration before moving controls: max3 per side, no duplicates,
foreign parents, ancestors/cycles or text buttons. Leading/trailing getters return defensive array copies.
Detached controls remain caller-owned. If the title cannot fit, fits=false/fits_changed
flags it and only the title hides; action slots are retained. In unsupported viewports
narrower than both lanes, slot nodes do not overlap but may extend beyond the bar: callers
must select fitting configurations. This is not a promise that arbitrary oversized widgets fit.

Transparent is the Level default; solid mode reads current Palette.SURFACE. Title reads
translated copy exactly once (automatic translation disabled on the Label). The component
owns duplicate imported Translation resources through native ResourceLoader/TranslationServer,
without a service dependency, and releases only its copies. Title fit uses independent native font shaping so a hidden Label cannot retain a stale
wrapped minimum after widening. Initial zero-size and narrow→wide recoveries are tested.
Theme/locale and slot minima
refresh layout; all manually connected signals disconnect on exit/reconnect on re-entry.

Gallery's Scaffold page shows passive official icons, header, body, footer and a generated
Palette-gradient art fixture. Icons are passive samples, not unimplemented action widgets.
Production screens receive scaffold behavior but retain their existing P1 headers until
screen integration tasks. No theme/token/export/project/settings/persistence changes.

Verification: nine new GUT tests plus all existing tests unchanged. Tests cover window
conversion, exact boundaries, signal deduplication, fraction/clamp/cap/asymmetric centre,
viewport resize/re-entry, art/theme, chrome ownership/order, atomic TopBar validation,
centred non-overlapping lanes, unsupported narrow state, locale/pseudo and independent
translation ownership. Native Compatibility previews:3 classes ×PL/PSEUDO ×default100/HC130
with fake insets, under ignored builds/T-0212-preview. Existing game startup also captured
without a native script/font error. PR records make check, independent review and final CI.

Local captures do not replace Chris's physical-device/taste acceptance, iPad/art decisions,
Opus audit or phase-exit gates. This remains a stacked draft until parent merges/manual gates.
