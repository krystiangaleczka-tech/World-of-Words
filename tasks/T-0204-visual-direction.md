---
id: T-0204
title: Compare three visual directions for the Level screen
epic: E12
type: docs
area: ui.tokens
risk: medium
executor: sol
think: high
ui: high
status: review
depends_on: [T-0203]
touch:
  - docs/design/T-0204/**
  - tasks/T-0204-visual-direction.md
revision: 1
---

## Goal
Give Chris three comparable Level mockups and a verbal moodboard to choose on his phone.
Deliver HTML/CSS references with semantic token names, not production screens.

## Context
- `docs/DESIGN.md#how-we-work`: "Chris picks on his phone browser."
- `docs/DESIGN.md#tokens-css-mirror`: "Group.NAME -> --Group-NAME" (case kept).
- `docs/DESIGN.md#level-p2-final`: use the Level component tree and one control per corner.
- Roadmap T-0204; background `docs/design-pass/10-ui-ux.md` sections 1 and 7.
- `docs/decisions/0010-p2-planning-order.md` limits its exception to T-0200..T-0203;
  the new, separately authorized T-0204 exception is recorded below.

## Current state
- `docs/DESIGN.md` defines palette, typography, layout, component and CSS-mirror contracts.
- `game/ui/tokens.gd` contains provisional P1 tokens; accepted values belong to T-0206.
- T-0203 is done. No T-0204 task or `docs/design/` mockups exist on source
  `ab67ff04b72b47b13cfab6cf34b4dd8aa19c8d1b`. T-0143 has no task file or verified FUN PASS.

## Specification
1. Provide three named directions with mood, material, typography and tradeoffs; identical
   sample crossword, wheel and HUD enable comparison. No selected/accepted direction by default.
2. Link full-viewport phone previews from an offline comparison page. Use no remote assets,
   tracking, build step or new dependency. Reviewer controls stay outside the game screen.
3. Use case-preserving CSS mirrors for palette, type, space, radius, elevation, motion, touch
   and layout. State the design-pixel conversion once. Explain mockup-only layout helpers.
4. Show filled/empty/hinted cells (hint dot), a selected chain, preview, BonusMeter and the
   P2 controls. Numbers are illustrative snapshots, not economy or unlock changes.
5. Include review modes for high contrast, 130% text, pseudo-locale and an eight-letter wheel.
   Keep all review states deterministic; these are static visual references, not a game demo.
6. Record repeatable browser checks and screenshots for COMPACT, REGULAR and TABLET.
   Keep review open for Chris's phone choice and actual device screenshots.

## UX
Reference: `docs/DESIGN.md#level-p2-final`. HTML representations of ScreenScaffold,
IconButton, CurrencyPill, BoardView/GridCell, BonusMeter, WordPreview, LetterWheelView/
LetterTile and HintButton only. PL display copy maps to keys in the mockup source.

Quoted rules from `DESIGN.md#rules-quote-these-into-ui-tasks`:
- **R-UI-1** A screen task may not create a component. If a needed component or state is missing,
  STOP (S4) and request a separate `ui.components` task.
- **R-UI-2** New component = separate task (`area: ui.components`), including its gallery entry.
- **R-UI-3** No raw numbers in scenes or feature scripts: use Tokens, theme variations/constants.
- **R-UI-4** Strings shown to players use translation keys, never literals.
- **R-UI-5** Never edit `game/ui/theme/generated/`. Change tokens, rerun the generator.
- **R-UI-6** Every UI PR with UI med/high attaches screenshots per the PR screenshot rules.
These are documentation mockups, not Godot components; labels and geometry have explicit
mockup mappings. System fonts are provisional; OFL/coverage/tnum verification is T-0205.

## Tests
- Open each direction offline at 360x640, 390x844 and 768x1024; no missing resources,
  console errors, horizontal overflow, board clipping or game-screen scrolling.
- Repeat with PSEUDO and 130% text, HC, eight letters and injected top/bottom safe insets.
  Check every displayed control is at least Touch.MIN_TARGET and no corner control
  intersects a tile hit circle (Touch.TILE_HIT_RATIO).
- Verify shown text/letter contrast >= 4.5:1 (HC >= 7:1), non-colour hinted/selected cues,
  semantic CSS variable resolution and deterministic review-mode links.
- Validate task metadata/scope; use repository CI for existing full checks (decision 0006).

## Acceptance
Deliverables and browser evidence reviewed; Chris selects a direction on his phone.
Do not mark done or transcribe values to runtime before that selection. Unavailable
checks/device evidence must be listed, not reported as passed.

## Out of scope
Game logic, gameplay input, production fonts/icons/art, other screens (T-0205), final
tokens (T-0206), theme generation, hosting, runtime files, economy and FUN gate closure.

## Escalation log
2026-10-12: Chris answered "Tak" to preparing the missing T-0204 specification and
mockups from the roadmap despite missing T-0143 evidence. This authorizes Codex/Sol
to prepare this bounded visual proposal in place of the planned Opus session.
T-0203 is the scheduling dependency for this exception; the roadmap's original T-0143
gate remains open for runtime work. No existing decision or roadmap is rewritten.
The exception does not select a visual direction or fabricate device evidence.
