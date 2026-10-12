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
COMPACT uses Space.S wheel-area padding. Other layouts reduce that padding to Space.S only
if necessary to preserve the minimum grid share. This is proposed geometry for review.
Standalone previews accept `direction=ceramic|paper|mist` and optional `hc=1`, `large=1`,
`pseudo=1`, `eight=1`, `insets=1`. No saved preference, network request, audio or motion.
The HC override preserves the existing token names; geometric letters remain unscaled at130%.
No Godot component, theme, font, registry or locale file is changed. HTML labels carry the
intended production key where applicable; icon aria labels describe the static fixture.

## Evidence and open gates

JavaScript syntax and local references are checked. Browser rendering/screenshot and touch-circle
assertions require a usable Chromium runtime: the current sandbox denies local socket operations
(`sandbox_host_linux.cc`, Operation not permitted); the permission-assisted run was interrupted.
No browser/device screenshots or visual PASS is claimed. Existing repository checks run through
CI (decision0006); actual results belong in the PR, not inferred from unchanged runtime files.
Test matrix: 360x640 COMPACT,390x844 REGULAR,768x1024 TABLET; PL/PSEUDO,130%,HC,eight
letters,44px top/34px bottom injected insets. Physical-device evidence remains Chris's.

Before T-0204 can be done: Chris opens the options on his phone, selects one (or requests a
specific mix), records actual device screenshots and confirms the reference. T-0206 must use
that explicit selection; current palette values must not be silently treated as approved.
