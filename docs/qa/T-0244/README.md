# T-0244 Home evidence

Home implements DESIGN.md#home / FR-META-05 using the catalog scaffold, currency pill, icon,
postcard, state panel and primary action. Its reading surface uses the existing catalog style
so location art cannot reduce text contrast. No reusable component or theme was introduced.

Reference: [Home mockup](../../design/T-0205/evidence/home_TABLET_PL_default.png).
The current shipped manifest has no location artwork; production therefore shows the explanatory
missing-art state and actual durable piece count. The gradient in partial/complete captures is
an injected review fixture, not final location art. Journey is hidden until T-0245 creates its
scene; Settings is disabled with explanatory tooltip until its screen exists. Daily/Collection
remain P3. The next-level caption is adjacent to Play because the existing ActionButton does not
support parameterized sublabels. Reference-device/taste review remains Chris's pending gate.

## Verification

Godot 4.7.2 ed1daf0bf: full make check passed 588/588 GUT, 329 pipeline and 500 tools tests;
formatting/lint, registries, content, UI strings and generated-theme guards passed. The final
Home composition also passed native X11/Mesa llvmpipe GUT: 9/9 tests, 133 assertions. Tests verify
committed values without writes, exact-slot partial-board restoration through the real Level,
failed routing, unavailable services (including absent/unloaded Config alone), terminal content, partial/complete art, copy/re-entry and
HC130/PSEUDO safe scrolling in all three layout classes. Existing tests were not changed.
Task lint: 180 tasks. Scope, independent exact-head review and CI results are recorded in the PR.

## Native screenshots

[capture.gd](capture.gd) reproduces these captures in a native X11 runtime after copying it into
an isolated Godot project as res://capture244.gd. Run the engine with --path <isolated-game>
--display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy -s res://capture244.gd.
The script writes only its own user:// capture save and these review PNGs. Fake safe insets are
24/48 viewport pixels on each side. PL/PSEUDO uses GalleryShell.OPTIONS (35% expansion, accents, no doubled vowels); default100/HC130
uses the shipped generated themes. Images are settled static UI, with no device certification claim.

| Capture | View |
|---|---|
| home_COMPACT_PL_default100_partial | [PNG](home_COMPACT_PL_default100_partial.png) |
| home_COMPACT_PL_hc130_partial | [PNG](home_COMPACT_PL_hc130_partial.png) |
| home_COMPACT_PSEUDO_default100_partial | [PNG](home_COMPACT_PSEUDO_default100_partial.png) |
| home_COMPACT_PSEUDO_hc130_partial | [PNG](home_COMPACT_PSEUDO_hc130_partial.png) |
| home_REGULAR_PL_default100_complete | [PNG](home_REGULAR_PL_default100_complete.png) |
| home_REGULAR_PL_default100_missing_art | [PNG](home_REGULAR_PL_default100_missing_art.png) |
| home_REGULAR_PL_default100_partial | [PNG](home_REGULAR_PL_default100_partial.png) |
| home_REGULAR_PL_default100_terminal | [PNG](home_REGULAR_PL_default100_terminal.png) |
| home_REGULAR_PL_hc130_partial | [PNG](home_REGULAR_PL_hc130_partial.png) |
| home_REGULAR_PSEUDO_default100_partial | [PNG](home_REGULAR_PSEUDO_default100_partial.png) |
| home_REGULAR_PSEUDO_hc130_partial | [PNG](home_REGULAR_PSEUDO_hc130_partial.png) |
| home_TABLET_PL_default100_partial | [PNG](home_TABLET_PL_default100_partial.png) |
| home_TABLET_PL_hc130_partial | [PNG](home_TABLET_PL_hc130_partial.png) |
| home_TABLET_PSEUDO_default100_partial | [PNG](home_TABLET_PSEUDO_default100_partial.png) |
| home_TABLET_PSEUDO_hc130_partial | [PNG](home_TABLET_PSEUDO_hc130_partial.png) |
