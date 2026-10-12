# T-0205 — Ceramic screen references

Status: **documentation references; Inter selected by Chris; phone/Q10/Q14 review pending**.
Source main ab67ff0; Ceramic input is T-0204 c4c85a4. T-0204's device evidence remains open.
The owner requested the next task and supplied the additional mockup. This bounded docs
continuation does not close FUN/device gates or adopt P2 runtime settings.

## Open
Open index.html offline, then its full-viewport links. No internet, build step, tracking,
persistence, purchases or production gameplay. Controls display catalog components.
Tutorial first-touch and coach dismissal are local review demonstrations only; they do
not evaluate a word, advance a slot, spend/grant anything or change a save.

The original extra owner reference is preserved byte-identically in reference-owner.html;
its path/hash are in sources.json. Its Papier/Szałwia/Piaskowiec palettes and interactive
prototype are supplementary context. They do not replace the selected Ceramic palette,
canonical unlocks, hint-dot treatment, or this task's catalog and translation-key mappings.

## Fixtures and components
| Reference | Catalog and states | Important boundary |
|---|---|---|
| Home | CurrencyPill, IconButton, LocationPostcard 2/4, ProgressBar, PrimaryButton, Journey NavTab | Daily/Collection hidden in P2 |
| Level complete | one earned star, illustrative +25 coins, 2/4 postcard, Continue, ad-badged x2 | eligible slot12, Q2 exactly one star |
| Journey | complete/current/locked Card + postcard | lock/check/play icon and copy, one synthetic region |
| Shop | Sheet + three Cards, one PrimaryButton, ad-badged free coins, iOS-only restore | canonical P2 product IDs, store price placeholders |
| Level1 | BoardView, WordPreview, wheel/tiles, TutorialHand and CAPTION | no settings, coins or gated controls |
| Coach marks | shuffle2, bonus5, hint7, reveal12, first Journey on Home | highlighted target + inline caption; no scrim/arrow; any tap dismisses |

All values and synthetic location names are illustrative display snapshots. No balance,
manifest, locale or registry changes. data-key/data-label-key contain proposed/canonical copy
mappings; coach/tutorial PL strings follow T-0201's approved teaching-plan proposals.
Hint3 and Reveal1 are illustrative inventory snapshots, not new grants or config defaults.
The complete screen's star fixture implements the accepted rule in GAME_DESIGN, not a
runtime award. Slot-based presence matches PRODUCT/DESIGN. Store prices are placeholders,
not hard-coded real prices, and Remove Forced Ads retains the honest title/body.

## Tokens and geometry
Tokens retain Group.NAME -> --Group-NAME and the design-px/2.6 conversion. Palette/shapes
inherit the selected Ceramic proposal. --Mock-* values are browser fixture helpers only.
Chris selected Inter on 2026-10-12 after viewing the PL/DE specimen: “Tak — wybieram
Inter”. The handoff uses fixed optical size14, cv08/cv05 alternates and numeric tnum.
Runtime font/theme import and physical-device readability checks remain later-task work.
The screenshots retain the pre-selection candidate wording as the comparison evidence.

Compact coach captions add space beside their targets. The proposed wheel floor is 450
design px instead of the T-0204 560px placeholder, and preview padding uses Space.XS. At that
floor the tile hit diameter still exceeds Touch.MIN_TARGET (450*.24*1.35=145.8 design px
versus144). The grid keeps GRID_MIN_RATIO and CELL_MIN, and captions ignore pointer input.
This is a visible geometry proposal for later accepted-token transcription, not a silent
runtime change. The same semantic minimum is used in all Level fixtures and the tests.

## Font, iPad and art handoff
- [Font decision0011](../../decisions/0011-fonts.md): owner-selected Inter as one family; Nunito's
  default tabular digits do not establish an explicit tnum feature. Unmodified font binaries,
  OFL notices and exact pinned URLs/hashes ship with these offline previews.
- [Font specimen](specimen.html): PL/DE, punctuation, I/l/1 and diacritics at tile size.
- [Q10 check](ipad-check.md): current Apple windowing/SDK findings; Q10 is not certified or
  silently closed. Portrait and resized-browser checks are not native iPad evidence.
- [Art brief/Q14](art-style.md): composition, material, four-piece masking, prompt/handoff and
  proposed Lucide icons. Artwork/tool/commercial-use adoption remains Chris's.

## Repeatable checks
Use an already installed HarfBuzz and Playwright/Chromium review runtime:

```sh
python3 docs/design/T-0205/check-font.py
BROWSER_TEST_MODULE=/absolute/path/to/playwright-core \
BROWSER_EXECUTABLE=/absolute/path/to/chromium \
node docs/design/T-0205/check-browser.cjs
```

Use --output for the font report or BROWSER_OUTPUT for browser output to keep repeat runs
outside tracked evidence. The browser blocks external requests and opens local file URLs.
It checks each screen at 360x640,390x844,768x1024 across all16 combinations of HC/130%/PSEUDO/
44px+34px insets, then resized 512x768/1024x768 windows and iOS Shop restore. Gestures separately
exercise tutorial normal/reduced first-touch and all five coach dismissals/unblocked input.
Menus and Sheet scroll internally; Level screens fit without scrolling. Screenshot animation
is disabled for deterministic capture. Font shaping checks used weights and actual features;
no project dependency is added. Assertions also enforce visible stamp dimensions/stroke,
count Badges, accessibility-key mappings and two-line coach/action labels clear of tile hit circles.
Repository checks and browser results are recorded below/PR.

## Evidence and acceptance
2026-10-12: Chromium 150.0.7871.24, **501 layout cases PASS** plus tutorial normal/reduced
first-touch and five coach dismissals/input checks. No console/resource errors or external
requests. Lowest text/icon contrast 4.918:1; HC 7.129:1. Minimum corner/tile
hit-circle clearance 15.526 CSS px; grid share 0.419967 (fractional browser-pixel tolerance). Source-reference hash is checked.
The evidence folder includes60 screen references, the comparison, three PL/DE font specimens
and the machine-readable font/browser reports. Full make check PASS:275 GUT,311 pipeline,
370 tools tests, registries and65 campaign levels. Final-head CI and fresh review belong in PR.
No unexecuted test, device screenshot, physical iPad observation, store review result or native
typography/a11y PASS is inferred.
Before done: Chris reviews phone references, native font readability and art choices; Q10 receives an explicit
owner/native follow-up disposition. These mockups do not make T-0206+ runtime work ready while
those decisions and the original gates remain open.
