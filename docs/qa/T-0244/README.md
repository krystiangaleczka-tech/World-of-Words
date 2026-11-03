# T-0244 Home evidence

Home implements DESIGN.md#home / FR-META-05 using the catalog scaffold, currency pill, icon,
postcard, state panel and primary action. Its reading surface uses the existing catalog style
so location art cannot reduce text contrast. No reusable component or theme was introduced.

Reference: [Home mockup](../../design/T-0205/evidence/home_TABLET_PL_default.png).
The current shipped manifest has no location artwork; production therefore shows the explanatory
missing-art state and actual durable piece count. The gradient in partial/complete captures is
an injected review fixture, not final location art. Journey uses the merged T-0245
scene; Settings is disabled with explanatory tooltip until its screen exists. Daily/Collection
remain P3. The next-level caption is adjacent to Play because the existing ActionButton does not
support parameterized sublabels. Reference-device/taste review remains Chris's pending gate.

## Revision 2 visual corrections

Owner approved the full postcard frame/shadow adjustment and component/test scope expansion.
Full uses Space.S / Elevation.LOW; thumb retains Space.M / Elevation.MID. Preset switching
refreshes both styling and geometry. This is an explicit owner override of DESIGN's MID token.
Home centers title and captions, uses a passive CatalogProgressBar derived only from committed
pieces, and removes the enclosing surface shadow. Missing-art copy is shorter and avoids
promising a specific content pack. Settings remains disabled; Journey routes the merged screen.
PR #171 was superseded by #172; this revision preserves #173/#174 on fresh main e3fe760.

Review follow-up: completion is stated once. Home hides the progress bar at full pieces, so
the postcard stamp (art) or the Progress caption (missing art) carries it. The full preset
reserves a mirrored icon slot, so its caption stays centred beside the stamp or lock. The
Status caption is centred like the other Home captions.

## Verification

Godot 4.7.2 ed1daf0bf: 642/642 GUT tests pass on main 6757e6d, including all Home, Journey and
Postcard cases. The additional tests cover passive Home progress/copy/no writes, the hidden bar
at completion, full/thumb styling across preset changes and the centred full caption beside the
stamp or lock. Full make check and scope results are recorded in the PR.
Native Apple M3 OpenGL/Metal captures cover all 15 states below; their run log contains no
errors or warnings. Reviewed REGULAR PL partial/missing-art and COMPACT PSEUDO HC130 against
the reference: centered progress is legible, frame/shadow is lighter, and Play stays reachable.
Reference-device/taste approval remains Chris's gate.

## Native screenshots

[capture.gd](capture.gd) reproduces these captures from the repository root:
`godot --path game --rendering-method gl_compatibility --audio-driver Dummy -s ../docs/qa/T-0244/capture.gd`.
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
