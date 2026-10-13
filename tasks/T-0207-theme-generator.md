---
id: T-0207
title: Generate six Ceramic theme foundations and the CSS token mirror
epic: E12
type: infra
area: ui.tokens
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0203]
touch:
  - game/ui/theme/**
  - game/tests/unit/ui/test_theme_generator.gd*
  - docs/design/tokens.css
  - tasks/T-0207-theme-generator.md
revision: 1
---

## Goal
Provide a repeatable editor/headless generator for the six Ceramic theme foundations.
Generate the CSS mirror from the same typed source, without activating a theme in the app.

## Context
- `docs/DESIGN.md#accessibility`: "theme_<default|hc>_<100|115|130>.tres" (six files).
- `docs/DESIGN.md#tokens-css-mirror`: "Group.NAME -> --Group-NAME" (case kept).
- `docs/DESIGN.md#tokensgd-shape`: Controls read styling from the active theme.
- Roadmap T-0207, FR-A11Y-03; T-0206 token source5bde59b is reviewed with12/12 CI PASS.

## Current state
- Fresh main ab67ff0 fast-forwarded to pinned T-0206 commit
  5bde59b5a550c7efa7dc8d9fb2939324ea3083e2 for an isolated stacked draft.
- Typed Tokens classes Palette/PaletteHC/Type/Space/Radius/Elevation/Motion/Touch/Layout/Ease
  and dur(milliseconds:int)->float exist; wheel floor450 and weights are accepted.
- docs/design/tokens.css exists with the complete v1 mapping documented in DESIGN.
- No game/ui/theme directory or generator exists. No Inter runtime assets/default theme.
- Existing components still use P1 local overrides; component migration belongs to later tasks.

## Specification
1. Add an @tool EditorScript with editor _run() entry and static generation helpers.
   Add a SceneTree headless adapter because Godot's CLI cannot run EditorScript as MainLoop.
   Document exact import/generation commands in game/ui/theme/README.md.
2. Generate exactly theme_default_100/115/130.tres and theme_hc_100/115/130.tres.
   Copy all semantic Palette names to theme type Palette using the selected palette.
   Set scaled theme default font size from BODY and all Type sizes under theme type Type;
   round scaled sizes to nearest integer. TILE_LETTER/PREVIEW remain unscaled;
   CELL_LETTER_RATIO stays geometry-bound and is not a fixed font size.
3. Provide Label type variations named Display/Title/Subtitle/Body/LabelText/Caption/Numeric/
   TileLetter/Preview with their appropriate sizes and text colours. Store canonical
   typography weight metadata under Type constants, including geometric cell-letter weight.
   Leave actual font resources unset: T-0208 imports Inter/FontVariation assets and binds weights.
   Do not claim fallback fonts implement the selected Inter weights or tnum.
4. Store Space/Radius and Elevation integer/colour metadata in the theme for later catalog
   components. Sizes/padding do not grow with text scale. Float geometry ratios remain in Tokens,
   not lossy integer Theme constants. Actual component styleboxes,
   outlines, focus/hit geometry and screen layout remain component/gallery tasks.
5. Generate docs/design/tokens.css mechanically from every typed Tokens nested-class constant,
   preserving the T-0206 units, Type name exceptions, full PaletteHC and active-HC remapping.
   Do not serialize reduced_motion or copy mockup helpers. Output order must be deterministic.
6. Save through ResourceSaver, create target directory as needed, report failure with nonzero
   CLI status. No new dependencies/autoloads, project.godot settings, imports or screen edits.
   Regeneration twice must produce byte-identical themes and CSS.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: No new component/state inside a screen task.
- R-UI-2: New component = separate ui.components task/gallery entry.
- R-UI-3: Visual values come from Tokens/theme.
- R-UI-4: Player text uses translation keys.
- R-UI-5: Never hand-edit generated themes; rerun the generator.
- R-UI-6: UI med/high PRs attach screenshot evidence per DESIGN.
These inactive theme foundations add no player screen. Preview evidence is a review fixture,
not a gallery/device acceptance substitute; existing UI acceptance gates stay open.

## Tests
File game/tests/unit/ui/test_theme_generator.gd:
- All six in-memory and saved themes have correct full palette, default font size and Type sizes.
- 115/130 text sizes increase; wheel/preview/cell geometry and padding do not scale.
- Canonical weights and Elevation metadata match Tokens; fonts remain explicitly unbound.
- Mutating one built theme does not mutate another, HC/default or source constants.
- Every saved theme loads and its contract matches a fresh build.
- Generated CSS is byte-identical to committed mirror; existing complete v1 parity test stays green.
- Run generation twice and compare all seven output hashes; make check, task/scope checks,
  fresh independent review and final-head CI must pass.

## Acceptance
Generator commands work, six loadable deterministic files and matching CSS are committed,
all checks pass. No generated file is manually edited and no theme/font is activated.

## Out of scope
Inter/FontVariation imports, actual component styles/focus outlines, project settings,
settings integration, screen/gallery migration, motion/save/economy/platform changes.

## Escalation log
2026-10-12: Chris requested “nastepny” immediately after reviewed T-0206 implementation.
Continue this bounded generator/tooling task on pinned T-0206 as a stacked draft PR so its
review diff contains one task. Scheduling dependency is done T-0203; the T-0206 input remains
review/unmerged. This is new task authorization, not an extension of decision0010 or a claim
that the T-0206-only exception closes other gates. No runtime theme/font activation or merge.
Original FUN/device/Opus/Q10/Q14 evidence stays open; merge the prerequisite before this PR.

Implementation evidence: Godot4.7.2 headless generation PASS; two independent processes
produce7/7 identical SHA256 outputs. make check PASS (281 GUT,311 pipeline,370 tools,
registries and65 content levels). No app theme/font activated. Fresh review/CI pending.
