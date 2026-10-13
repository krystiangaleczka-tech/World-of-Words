---
id: T-0205
title: Extend Ceramic to key screens and verify visual foundations
epic: E12
type: docs
area: ui.tokens
risk: medium
executor: sol
think: high
ui: high
status: done
depends_on: [T-0203]
touch:
  - docs/design/T-0205/**
  - docs/decisions/0011-fonts.md
  - tasks/T-0205-screen-mockups.md
revision: 1
---

## Goal
Give Chris comparable offline Ceramic references for Home, Level complete, Journey,
Shop sheet, first-level tutorial and coach marks. Verify the font candidate, document
current iPad constraints and specify a repeatable postcard/icon style for later art tasks.

## Context
- `docs/DESIGN.md#typography`: "Use one family if it passes all requirements."
- `docs/DESIGN.md#feature-unlock-gating`: coach marks are highlighted components plus
  inline CAPTION copy; "No overlay, no scrim, no arrow, no new component."
- `docs/DESIGN.md#tokens-css-mirror`: "Group.NAME -> --Group-NAME" (case kept).
- Roadmap T-0205; PRODUCT Q10/Q14; GAME_DESIGN onboarding and approved Q2.
- Owner-selected Ceramic: T-0204 commit c4c85a4f646e29c666c0ca0cc14fb2cb289a3222.

## Current state
- Source main ab67ff04b72b47b13cfab6cf34b4dd8aa19c8d1b has DESIGN screen/component,
  typography/layout contracts; PRODUCT canonical IDs and GAME_DESIGN P2 decisions.
- T-0203 task status is done. T-0204 is an open draft PR with Ceramic explicitly
  selected by Chris; actual phone screenshot evidence remains pending.
- Runtime tokens remain provisional. No T-0205 specification, final fonts, or its
  mockups exist on this source. Decision 0011 is unused.
- Chris additionally supplied local docs/design/T-0204-level-mockup.html. Preserve
  a byte-identical snapshot with hash and provenance; it is supplementary input,
  not a replacement for Ceramic or a production gameplay specification.

## Specification
1. Offline comparison with full-viewport links for Home, Level complete, Journey,
   Shop, slot-1 TutorialHand+caption and coach-mark states. Use Ceramic token mirrors
   and catalog representations only; map player labels/accessibility labels to keys.
2. Home shows P2 Journey only (no unbuilt Daily/Collection). Level complete shows one
   earned star (approved Q2), illustrative reward/postcard progress, Continue and
   optional ad-badged x2 at its eligible slot. Journey covers current/complete/locked.
   Shop uses canonical P2 IDs, honest Remove Forced Ads copy, price placeholders,
   optional ad-badged free coins, and iOS-only restore. No economy/config change.
3. Slot 1 has only board, preview, wheel, level label, tutorial and caption; no settings,
   currencies or gated controls. Coach marks cover shuffle/bonus/hint/reveal and Journey
   at their canonical slots. Inline labels never block input; any tap dismisses them.
   Tutorial hides on first wheel touch; reduced motion uses its static-path alternative.
   Reviewer controls stay outside the game. Review actions are demonstrations, not gameplay.
4. Verify Nunito first: pinned official binary, PL/DE/punctuation coverage, actual tnum
   shaping/equal advances, required weight range, diacritic rendering and licence.
   Bundle unmodified font+OFL only for these offline previews. Use installed review
   tools/engine, no project dependency. Record decision 0011 as proposed until owner accepts.
   Verify Inter only if Nunito fails a requirement; do not silently adopt two families.
5. Record Q10 against current primary Apple sources. Check portrait and resized browser
   windows; distinguish browser layout evidence from native iPad/SDK/store evidence.
   Report constraints without changing PRODUCT, project.godot, plist, permissions or SDKs.
6. Art style: palette/composition/material, four-piece postcard masking, scale/HC/legibility,
   prompt templates, asset/provenance/licence handoff, app-icon constraints and an icon-set
   recommendation. Art/tool choice Q14 stays explicit; no generated production postcard/icon.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: A screen task may not create a component; missing component/state → S4.
- R-UI-2: New component = separate ui.components task and gallery entry.
- R-UI-3: No raw values in scenes/features; use Tokens/theme values.
- R-UI-4: Player strings use translation keys, never literals.
- R-UI-5: Never edit generated themes; change tokens and rerun the generator.
- R-UI-6: UI med/high PRs attach screenshot evidence per DESIGN.
HTML labels/geometry are documented mockup mappings, not new Godot components.

## Tests
- Repeatable offline browser matrix at 360x640,390x844,768x1024: every screen in all
  combinations of HC/130%/PSEUDO/safe insets. Add 512x768 and 1024x768 resize cases.
- No errors/missing resources/external requests/horizontal overflow or clipped labels;
  menus scroll within their content region, Shop within Sheet <= SHEET_MAX_RATIO.
  Level variants never scroll. Targets >= Touch.MIN_TARGET; wheel/grid fit and corner
  targets never intersect tile hit circles. Text >=4.5:1, HC >=7:1; non-colour state cues.
- Assert actual mode effects, canonical gating, one PrimaryButton, ad badges, canonical
  product IDs, iOS-only restore and deterministic links. Exercise tutorial first-touch,
  reduced-motion alternative and coach any-tap dismissal without blocking wheel input.
- Font verification is repeatable, checks exact hashes/OFL, required coverage/weights,
  and equal tabular advances at used weights. Render PL/DE/digit/ambiguity specimens.
- Attach screenshots for all reference classes and PL/PSEUDO stress. Run make check,
  task/scope checks, fresh independent review and final-head CI.

## Acceptance
All deliverables and automated evidence reviewed. Chris confirms phone references,
font and Q10/Q14 dispositions; actual device evidence is recorded, not inferred.
Keep review open if those gates remain unavailable. Runtime adoption waits for T-0206+.

## Out of scope
Runtime/UI components/themes/locales/config/economy/save/analytics, production art/icon import,
hosting, native iPad proof, signing/plist/export settings, and closing FUN/T-0204 device gates.

## Escalation log
2026-10-12: Chris instructed "rob kolejny task" and supplied the additional mockup after
explicitly choosing Ceramic. This authorizes preparation and execution of this bounded next
roadmap documentation task by Codex/Sol. T-0203 is its scheduling dependency while unmerged
T-0204 remains a pinned design input; its missing device evidence is preserved. This does not
extend decision 0010 to runtime work or claim an Opus review. No roadmap or old decision changes.

## Owner review record
2026-10-12: Chris saw the PL/DE specimen and selected Inter for further work:
“Tak — wybieram Inter”. Decision 0011 records that selection. Physical phone/iPad
evidence, native font readability, Q10/Q14 dispositions and required Opus review remain
open; task status stays review. No runtime resources or settings were changed.
