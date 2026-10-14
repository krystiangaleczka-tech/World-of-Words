# T-0245 Journey native evidence

Reference: [Journey mockup](../../design/T-0205/evidence/journey_COMPACT_PL_default.png),
DESIGN.md#journey-1-region, PRODUCT FR-META-04 and FR-PROG-06.

Home's existing Journey tab now opens an actual screen; Back returns through guarded navigation.
One current region shows complete/current/locked locations, durable stars and independent postcard
credits. Completed level ranges are informational, with no replay actions. Current cards have a
border and explicit text; locked cards have a lock Badge, disabled input and unlock-slot caption.
Long region names move into a wrapped heading when TopBar cannot fit them. All content uses the
existing component catalog, tokens and generated themes. No grants or persistence writes.

The shipped legacy content has only virtual campaign metadata and no art. Captures deliberately
use [test-only catalog metadata](../../../game/tests/fixtures/journey/catalog.gd) with three sample
locations and an injected gradient; these are not final content or artwork. Production falls back
to a translated name/art caption and the actual durable progress. Selecting/postcard details are
T-0246: cards remain passive with an explicit coming-soon explanation rather than opening an empty
POSTCARD destination. No second-region teaser is shown. Device screenshots/taste approval remain
Chris's pending gate; desktop evidence does not certify physical devices.

## Verification

Godot 4.7.2 ed1daf0bf, native X11/Mesa llvmpipe: final Journey 11/11 tests, 185 assertions; existing
Home suite 9/9 tests, 137 assertions, including its newly implemented Journey route/Back behavior.
Coverage includes committed values without file writes, missing/unloaded services and language
mismatch, unsupported piece capacity, multi-level completed ranges, independent campaign/postcard
completion, terminal/current-region selection, missing/injected art, Back errors, locale and owned
Card-body refresh/exit/re-entry cleanup. No orphans in either focused native suite. Safe-layout
assertions pass in COMPACT/REGULAR/TABLET with HC130 and 35% pseudolocalization. Native
touch-emulation mouse drags scroll when started over a passive card. The test fails in all three
classes when the two pointer-pass-through settings are reverted in an isolated project. Full make check,
exact-head independent review, task/scope and all14CI results are recorded in the PR before merge.

## Reproduction and matrix

Copy [capture.gd](capture.gd) into an isolated imported Godot project as res://capture245.gd.
Run --path <isolated-game> --display-driver x11 --rendering-method gl_compatibility
--audio-driver Dummy -s res://capture245.gd. The script uses its own temporary user:// capture
save and emits these PNGs; reduced motion stabilizes static captures. GalleryShell.OPTIONS sets
35% expansion, accents and no doubled vowels. Themes are default100 and HC130. Fake safe insets
are 24/48 viewport pixels per side. Each matrix state has top/bottom scroll captures so locked
content is included. Missing-art and complete-region captures are REGULAR/PL/default100.

| Capture | Image |
|---|---|
| journey_COMPACT_PL_default100_states_bottom | [PNG](journey_COMPACT_PL_default100_states_bottom.png) |
| journey_COMPACT_PL_default100_states_top | [PNG](journey_COMPACT_PL_default100_states_top.png) |
| journey_COMPACT_PL_hc130_states_bottom | [PNG](journey_COMPACT_PL_hc130_states_bottom.png) |
| journey_COMPACT_PL_hc130_states_top | [PNG](journey_COMPACT_PL_hc130_states_top.png) |
| journey_COMPACT_PSEUDO_default100_states_bottom | [PNG](journey_COMPACT_PSEUDO_default100_states_bottom.png) |
| journey_COMPACT_PSEUDO_default100_states_top | [PNG](journey_COMPACT_PSEUDO_default100_states_top.png) |
| journey_COMPACT_PSEUDO_hc130_states_bottom | [PNG](journey_COMPACT_PSEUDO_hc130_states_bottom.png) |
| journey_COMPACT_PSEUDO_hc130_states_top | [PNG](journey_COMPACT_PSEUDO_hc130_states_top.png) |
| journey_REGULAR_PL_default100_missing_art_bottom | [PNG](journey_REGULAR_PL_default100_missing_art_bottom.png) |
| journey_REGULAR_PL_default100_missing_art_top | [PNG](journey_REGULAR_PL_default100_missing_art_top.png) |
| journey_REGULAR_PL_default100_region_complete_bottom | [PNG](journey_REGULAR_PL_default100_region_complete_bottom.png) |
| journey_REGULAR_PL_default100_region_complete_top | [PNG](journey_REGULAR_PL_default100_region_complete_top.png) |
| journey_REGULAR_PL_default100_states_bottom | [PNG](journey_REGULAR_PL_default100_states_bottom.png) |
| journey_REGULAR_PL_default100_states_top | [PNG](journey_REGULAR_PL_default100_states_top.png) |
| journey_REGULAR_PL_hc130_states_bottom | [PNG](journey_REGULAR_PL_hc130_states_bottom.png) |
| journey_REGULAR_PL_hc130_states_top | [PNG](journey_REGULAR_PL_hc130_states_top.png) |
| journey_REGULAR_PSEUDO_default100_states_bottom | [PNG](journey_REGULAR_PSEUDO_default100_states_bottom.png) |
| journey_REGULAR_PSEUDO_default100_states_top | [PNG](journey_REGULAR_PSEUDO_default100_states_top.png) |
| journey_REGULAR_PSEUDO_hc130_states_bottom | [PNG](journey_REGULAR_PSEUDO_hc130_states_bottom.png) |
| journey_REGULAR_PSEUDO_hc130_states_top | [PNG](journey_REGULAR_PSEUDO_hc130_states_top.png) |
| journey_TABLET_PL_default100_states_bottom | [PNG](journey_TABLET_PL_default100_states_bottom.png) |
| journey_TABLET_PL_default100_states_top | [PNG](journey_TABLET_PL_default100_states_top.png) |
| journey_TABLET_PL_hc130_states_bottom | [PNG](journey_TABLET_PL_hc130_states_bottom.png) |
| journey_TABLET_PL_hc130_states_top | [PNG](journey_TABLET_PL_hc130_states_top.png) |
| journey_TABLET_PSEUDO_default100_states_bottom | [PNG](journey_TABLET_PSEUDO_default100_states_bottom.png) |
| journey_TABLET_PSEUDO_default100_states_top | [PNG](journey_TABLET_PSEUDO_default100_states_top.png) |
| journey_TABLET_PSEUDO_hc130_states_bottom | [PNG](journey_TABLET_PSEUDO_hc130_states_bottom.png) |
| journey_TABLET_PSEUDO_hc130_states_top | [PNG](journey_TABLET_PSEUDO_hc130_states_top.png) |
