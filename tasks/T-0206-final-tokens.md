---
id: T-0206
title: Transcribe accepted Ceramic values into v1 design tokens
epic: E12
type: contract
area: ui.tokens
risk: high
executor: sol
think: med
ui: high
status: blocked
depends_on: [T-0205]
touch:
  - game/ui/tokens.gd
  - game/tests/unit/ui/test_tokens.gd
  - game/tests/unit/ui/test_p1_tokens.gd
  - game/tests/unit/ui/test_v1_tokens.gd
  - docs/design/tokens.css
  - docs/DESIGN.md
  - tasks/T-0206-final-tokens.md
revision: 1
---

## Goal
Make the accepted Ceramic values the v1 token contract shared by Godot and HTML.
Preserve the existing Tokens API and behavior while making the CSS mirror complete.
This task does not implement the final Level composition or import fonts.

## Context
- `docs/DESIGN.md#tokens`: "All values in this section are provisional until the visual-direction task."
- `docs/DESIGN.md#tokens-css-mirror`: "Group.NAME -> --Group-NAME" (case kept).
- `docs/DESIGN.md#tokensgd-shape`: Control-based components read styling from the active theme.
- Roadmap T-0206 depends on accepted T-0205; later T-0207 owns the theme generator.
- Pinned review inputs: T-0204 c4c85a4 and T-0205 5eaa29c, not yet merged.

## Current state
Verified on main ab67ff04b72b47b13cfab6cf34b4dd8aa19c8d1b, 2026-10-12:
- `game/ui/tokens.gd`: class_name Tokens extends RefCounted. Nested classes Palette,
  PaletteHC, Type, Space, Radius, Motion, Touch, Layout and Ease exist with typed constants.
- `Tokens.reduced_motion: bool` and `Tokens.dur(milliseconds: int) -> float` exist.
  Negative durations clamp to zero; reduced motion preserves FAST and suppresses longer motion.
- `game/tests/unit/ui/test_tokens.gd` asserts provisional palette values and purity.
  `game/tests/unit/ui/test_p1_tokens.gd` asserts duration and geometry relationships.
- No `docs/design/tokens.css`, T-0205 task, or its accepted mockups exist on this main.
  PR129 and PR130 remain draft, with physical-device/Opus/Q10/Q14 gates open.
- Ceramic and Inter have owner selections, but the complete mockup geometry has not
  received an explicit runtime-adoption disposition. No runtime exception is inferred.

## Specification
### Behavior
1. Before implementation, rebase onto main after T-0205 is done. Re-run preflight and pin
   its accepted source SHA. If Chris authorizes a different ordering, record the exact
   bounded exception without marking missing device/Opus evidence as completed.
2. Transcribe every Palette colour from the accepted Ceramic reference; PaletteHC must
   have exactly the same semantic names. Retain existing typed constant names and types.
   Do not remove the P1 geometry additions that current views consume.
3. Retain the canonical Type sizes, Space, Radius, Motion, Touch and Ease values unless
   the accepted reference explicitly changes them. Record the complete v1 values and
   provenance in DESIGN, including any approved Layout delta; no inferred adjustments.
4. Preserve the Type integer size API and duration behavior. Add no font resources,
   singleton, settings state or new player-facing text. Font-family/feature implementation
   remains T-0208; its accepted Inter decision is an input, not an asset import here.
5. Add docs/design/tokens.css with the complete semantic mirror of the final constants:
   design px / 2.6 for lengths, ms for motion, raw dimensionless ratios, all Type sizes
   and canonical weights. Include complete default and high-contrast palettes. Document
   mechanical mappings for existing compound/vector values; never ship Mock-* fixture
   values, viewport insets, system-font fallbacks or coach-only CSS as runtime tokens.
6. Do not change the screen scenes/scripts to make them resemble the mockup here.
   Some existing P1 views consume Tokens directly and will pick up new palette values;
   final wheel/board/composition styling remains T-0222/T-0223/T-0276.

### Unresolved source values (S4)
T-0205 tokens.css retains WHEEL_MIN=560, but screens.css overrides it to450 for inline
coach captions; README explicitly labels450 a proposal. DESIGN and current Godot use560.
Chris must select the accepted v1 value before item3 is implemented. At450 the existing
hit-diameter formula gives145.8 >=144; browser evidence does not certify native layout.
Preview-strip Space.XS in T-0205 also requires an explicit adoption disposition for later
screen styling; this task cannot silently change screen code.

### UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: A screen task may not create a component; missing component/state -> S4.
- R-UI-2: New component = separate ui.components task and gallery entry.
- R-UI-3: No raw values in scenes/features; use Tokens/theme values.
- R-UI-4: Player strings use translation keys, never literals.
- R-UI-5: Never edit generated themes; change tokens and rerun the generator.
- R-UI-6: UI med/high PRs attach screenshot evidence per DESIGN.
No generated theme exists for this task; T-0207 creates it. Attach the accepted HTML
references and actual current-screen screenshots if direct-token consumers change.

## Tests
- Update `game/tests/unit/ui/test_tokens.gd` to assert selected Ceramic values rather
  than obsolete provisional colours; retain RefCounted/no-Node assertions.
- Keep all duration and geometry assertions in `game/tests/unit/ui/test_p1_tokens.gd`.
  Changing expected values must be justified by the recorded accepted contract.
- Add `game/tests/unit/ui/test_v1_tokens.gd`: default/HC semantic parity; complete CSS
  mirror with correct values/units; Type weights and ratios; colour contrast >=4.5 normal
  and >=7 HC for declared text/background pairs; tile-hit floor >=Touch.MIN_TARGET.
  Mirror tests must fail for a wrong CSS value, missing HC entry or changed Godot value.
- Run make check, scope/task lint, fresh independent contract review and final-head CI.
  A task-preparation-only commit does not claim these implementation tests exist/pass.

## Acceptance
Every specified value comes from the accepted source and is represented in Godot/CSS.
Tests and make check pass; fresh review/CI pass. Actual phone verification covers any
changed P1 rendering. Original FUN/Opus/iPad/art/native-font gates retain their provenance.

## Out of scope
Font import, theme generator/generated themes, final screen/components/layout algorithms,
config/economy/save/analytics, project.godot/export/platform permissions and signing.

## Rollback
Revert this task to restore provisional styling; no save/content migration is required.

## Escalation log
2026-10-12 — S1/S4, preflight preparation only: T-0205 is unmerged and not done; its task
is absent on main. WHEEL_MIN450 remains an unaccepted mockup proposal versus current560.
Prepared this blocked specification on fresh main; no runtime files changed. Draft PR
records the blocker. Options: finish/merge the prerequisite and accept geometry, or Chris
explicitly authorizes bounded ordering plus selected v1 geometry. Existing documentation
ordering exception0010 does not authorize this runtime task. Await disposition.
