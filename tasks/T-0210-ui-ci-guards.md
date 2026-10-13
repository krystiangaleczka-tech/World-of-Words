---
id: T-0210
title: Enforce UI token and translation literals and generated theme freshness
epic: E14
type: infra
area: ci
risk: medium
executor: sol
think: med
ui: none
status: done
depends_on: [T-0132, T-0203]
touch:
  - tools/check_tokens.py
  - tools/check_strings.py
  - tools/check_theme.py
  - tools/ui_checks.py
  - tools/tests/test_ui_checks.py
  - tools/tests/test_check_theme.py
  - Makefile
  - .github/workflows/ci.yml
  - docs/qa/T-0210-ui-ci-guards.md
  - tasks/T-0210-ui-ci-guards.md
revision: 1
---

## Goal
Fail local make check and CI when feature/component UI introduces raw visual values,
literal player copy or stale generated theme/font/CSS outputs. Keep diagnostics actionable.

## Context
- ROADMAP T-0210; DESIGN.md#rules-quote-these-into-ui-tasks R-UI-3/R-UI-4/R-UI-5.
- R-UI-3: use Tokens/theme constants for colours, font sizes, margins/radii and durations.
- R-UI-4: player strings use translation keys; R-UI-5: rerun generator, never hand-edit theme.
- FR-LOC-02; T-0132 locale catalogue is done. Pinned reviewed T-0207/T-0208 generator inputs.

## Current state
- Fresh main ab67ff0 fast-forwarded to reviewed T-0209 0014501 (12/12 CI PASS); stacked draft.
- tools/check_registries.py uses installed gdtoolkit parser/Lark metadata; no new dependency needed.
- Feature/component GDScript uses Tokens; Color(Tokens.Palette.TEXT, alpha) is valid opacity
  adaptation and Color.WHITE is identity modulation. Translation format punctuation is valid.
- Makefile check currently runs fmt/lint/import/GUT/pipeline/tools/registries/content.
- generate_theme_cli.gd runs the T-0208 generator and writes 14 outputs: six themes, Inter.res,
  five FontVariations, font_license.tres and docs/design/tokens.css. Existing generation is deterministic.
- No UI literal or freshness checker exists. CI container has pinned Godot and uv installed.

## Specification
1. Add AST-backed, fail-closed parsing checks for *.gd and property checks for *.tscn in
   game/features/** and game/ui/components/** only. Ignore comments/string content as code.
   Do not scan tokens, generated assets, gallery, addons, tests or core.
2. Token guard rejects literal Color constructors/factories, hexadecimal colour strings,
   positive numeric duration arguments to tween_property/method/interval, numeric font-size/
   theme-constant override values and literal visual property assignments (font size,
   content margins, corner radii, minimum size/offsets). Neutral 0/1/-1 layout values are
   allowed. Preserve dynamic values, identity Color.WHITE and token colour with dynamic alpha.
   TSCN checks cover corresponding Color/theme/font/margin/radius/duration properties.
3. String guard checks text/tooltip/placeholder/accessibility-name assignments, set_text/
   set_tooltip_text/add_item/add_tab and draw_string text arguments, including nested literals.
   Translation calls protect only their key argument, not unrelated concatenated literal text.
   Empty strings, punctuation and numeric/printf format-only strings are allowed; content
   words outside translation calls fail. TSCN static text values fail unless empty or a
   registered locale CSV key. Dynamic gameplay letters/words remain valid.
   Unknown literal tr() keys fail against CSV catalogue. No interprocedural/dataflow claim.
4. Diagnostics identify relative path, source line and violated rule. Malformed scripts/scenes,
   missing required scan directories or locale catalogue fail; no blanket allowlist/baseline.
   CLIs accept --root for fixture use and return nonzero on errors.
5. Theme freshness checker regenerates in a temporary copied project (without .godot cache),
   checks import/generation errors/warnings and compares all 14 bytes with source outputs.
   Missing/different output fails with its path and regeneration command; source repo stays
   unchanged, including on failure. Accept --root and --godot; engine errors fail nonzero.
6. Add make ui-check (static guards) and theme-check (freshness); include both in make check.
   Add one CI UI-guards job invoking both; Android jobs depend on it. Existing checks stay intact.
   No runtime, dependency, project/export/platform/signing or source-of-truth rules change.

## Tests
- tools/tests/test_ui_checks.py: failing/valid colours, numeric multiline durations, token alpha,
  theme sizes/margins, comments and string traps, scoped exclusions, GDScript parse error,
  missing scan roots, literal/nested player copy, translated keys and format-only strings,
  unknown keys, scene copy/visual values and malformed scene properties; CLI exit/diagnostics.
- tools/tests/test_check_theme.py: fake engine produces matching/changed/missing outputs,
  import/generator failure and warnings; temp-only mutation, missing source output and CLI
  exit/diagnostics; all 14 output paths covered.
- Run real pinned-engine freshness check, make check, task/scope lint, independent review
  and final-head CI. Mutation probe must fail if an actual generated theme is hand-edited.

## Acceptance
All required tests pass; real clean-cache generation matches all outputs; fresh drift is
rejected without mutating source; make check/CI enforce both guards and Android gating.

## Out of scope
Runtime/component refactors, new gameplay copy, new dependencies, font/theme regeneration
changes, save/economy, permissions/signing/export settings, ROADMAP updates and manual gates.

## Escalation log
2026-10-12: owner next-task request authorizes the bounded CI/tooling handoff on the reviewed
runtime/asset stack. T-0132 and T-0203 are done. Pinned generator parents must merge first;
previous taste/device/Opus/Q10/Q14 gates remain open. Workflow edits add checks only and do
not change credentials, endpoint or signing behavior.
