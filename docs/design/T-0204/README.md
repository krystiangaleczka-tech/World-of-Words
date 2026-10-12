# T-0204 — Level visual directions

Status: **three proposals, awaiting Chris's phone choice**. Nothing here is an accepted
reference or runtime design. Source: `ab67ff04b72b47b13cfab6cf34b4dd8aa19c8d1b`.

## Open and compare

Download this directory as a bundle and open `index.html` in a browser, or serve the repository:
`python3 -m http.server 8000`, then visit `/docs/design/T-0204/`. No build or internet is required.
The comparison page has three full-screen links and reviewer switches; game controls are static
visual representations, explicitly described as such on the comparison page. On a phone use
the full-screen links. Browser back returns to the comparison.

| Direction | Verbal moodboard | Tradeoff |
|---|---|---|
| Ceramic / Ceramika | Warm ivory, matte clay, green glaze, gently raised tiles. Rounded letters, restrained outlines. A quiet everyday ritual. | Most friendly; shadows and warm hinted cells need deliberate HC treatment. |
| Paper / Papier | Cream stationery, terracotta ink, straight edges, no shadows. Human, tactile, orderly. | Strong character; tighter corners can feel more like a traditional crossword. |
| Mist / Mgła | Light stone, muted blue, open space, softer geometry. Clear, light, spacious. | Airiest; avoid becoming cold or resembling a utility app. |

All three share the same crossword and Level12 illustrative snapshot: coins240, bonus3/10,
Hint3, Reveal250. These are display fixtures, not registry changes. LAS is filled; LATO crosses
through L; STO crosses through T. The hinted A has a dot. L/A selection has a connection line,
outline and enlarged tiles, so neither state depends only on colour. Eight-letter mode includes
Ż/Ó/Ł to expose diacritic clipping. System font stacks are provisional: glyph/tnum/OFL adoption
and production icon selection belong to T-0205.

## Contract and handoff

`level.css` states the one design-pixel conversion. CSS mirrors keep the exact case in
`Group.NAME -> --Group-NAME`; type size/weight split follows DESIGN. `--Mock-*` helpers belong
only to browser review (computed cell/wheel geometry, text scale and simulated safe insets).
COMPACT uses Space.S wheel-area padding. The wheel first shrinks towards WHEEL_MIN to keep
GRID_MIN_RATIO; other layouts reduce padding to Space.S if the minimum wheel still cannot
fit that budget. Cell fitting uses fractional browser geometry, avoiding subpixel clipping.
This is proposed geometry for review. Safe insets affect the actual layout class, so the
360x640 reference becomes TABLET with the injected 44px/34px insets; the report records it.
Standalone previews accept `direction=ceramic|paper|mist` and optional `hc=1`, `large=1`,
`pseudo=1`, `eight=1`, `insets=1`. No saved preference, network request, audio or motion.
The HC override preserves the existing token names; geometric letters remain unscaled at130%.
Eight-letter mode proposes TILE_RADIUS_RATIO 0.105 (five-letter mode 0.12), keeping enlarged
selected rectangles clear of neighbouring tiles. This is an unaccepted mockup value; the
runtime geometry decision belongs to the later accepted-token/component tasks.
No Godot component, theme, font, registry or locale file is changed. HTML labels carry the
intended production key where applicable; icon aria labels describe the static fixture.

## Repeatable browser checks

`check-browser.cjs` uses an already installed Playwright runtime and Chromium. It adds no
repository dependency. Point the two environment variables to that existing installation:

```sh
BROWSER_TEST_MODULE=/absolute/path/to/playwright-core \
BROWSER_EXECUTABLE=/absolute/path/to/chromium \
node docs/design/T-0204/check-browser.cjs
```

Use `BROWSER_OUTPUT=/temporary/path` to keep a repeat run outside the tracked evidence folder.
The runner opens local `file:` URLs and blocks external requests. It checks each direction at
360x640, 390x844 and 768x1024 with all 32 combinations of HC, 130% text, PSEUDO, eight letters
and injected 44px/34px safe insets (288 cases), then three live resizes. Assertions cover scroll,
safe-content bounds, fractional grid fitting, grid share, wheel/cell minimums, touch targets,
button/tile hit-circle separation, displayed text/icon contrast including alpha, non-colour
cues (painted hint dot, visible outlines, visible chain joining selected centres), pairwise
tile separation, actual review-mode effects, token resolution, resource/console errors and
deterministic comparison links.

## Evidence and open gates

2026-10-12: Chromium 150.0.7871.24, **291 cases PASS**, no console/resource errors and no
external requests. Lowest displayed contrast: **4.848:1**, HC **7.129:1**. Minimum corner-button
clearance from a tile hit circle (including selected visual enlargement): **13.891 CSS px**.
Minimum grid share: **0.420028**. The previous sandbox limitation no longer applies.
The evidence folder contains the full JSON report, 27 Level screenshots (PL default, PSEUDO
stress and PSEUDO stress HC for each direction/viewport) and a comparison screenshot.

Browser checks exposed and corrected a too-small currency touch target, slightly insufficient
grid share, fractional-pixel grid clipping and reduced contrast on the preview's dot cue.
Eight-letter tile sizing also keeps selected corners from overlapping their neighbours.
These corrections only affect the documentation mockups.

Full local `make check` PASS: 275 GUT tests, 311 pipeline tests, 370 tools tests, registries and
65 campaign levels. Task metadata: 138 tasks PASS. The original PR head also passed all 12 CI
jobs; final-head CI results belong in the PR. [Side-by-side preview](evidence/comparison_DESKTOP_PL_default.png)
and [machine-readable report](evidence/browser-results.json) are browser evidence, not device evidence.

Before T-0204 can be done: Chris opens the options on his phone, selects one (or requests a
specific mix), records actual device screenshots and confirms the reference. T-0206 must use
that explicit selection; current palette values must not be silently treated as approved.
