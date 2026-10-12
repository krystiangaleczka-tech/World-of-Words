---
id: T-0219
title: Add bonus chest progress and counted power-up buttons
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: med
ui: med
status: review
depends_on: [T-0218]
touch:
  - game/ui/components/BonusMeter.gd*
  - game/ui/components/BonusMeter.tscn
  - game/ui/components/HintButton.gd
  - game/ui/theme/generate_theme.gd
  - game/ui/tokens.gd
  - docs/design/tokens.css
  - game/ui/gallery/powerups.gd*
  - game/ui/gallery/powerups.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/ui.csv
  - game/locale/gallery.csv
  - game/tests/unit/ui/test_v1_tokens.gd
  - game/tests/integration/test_bonus_hint_catalog.gd*
  - docs/qa/T-0219-bonus-hint.md
  - tasks/T-0219-bonus-hint.md
revision: 1
---

## Goal
Present caller-configured bonus progress and power-up count/price with native action states.
Preserve P1 free hint behavior until final configuration is explicitly invoked.

## Context
DESIGN.md#bonusmeter, #hintbutton, #level-motion, #reduced-motion-mapping.
BONUS/Numeric; already pulse1.06 twiceFAST/IN_OUT. Economy numbers supplied by callers/config.

## Current state
Fresh main857528c contains T-0218,372GUT. CatalogAction/CatalogProgressBar/IconButton/Badge and
LocaleCatalog exist. HintButton extends IconButton, init text_key=level.hud.hint; Level overrides
free-hint key and native disabled/pressed. No BonusMeter. Owner serial technical handoff authorized.

## Specification
1. BonusMeter extends CatalogAction: configure(count:int,target:int)->Error atomically rejects
   negative count/nonpositive target; count/target read-only, exact integer ratio caption. Count above
   target remains exact but normalized fill caps1. Target comes from caller, no Config/Economy calls.
   set_count(count:int,animate:bool=true)->Error requires configured target; invalid preserves tween.
2. State normal|filling|full|already|highlighted; CatalogProgressBar BONUS fills BASE/OUT. Official
   gift/chest icon and translated Open label appear full. Only settled full meter accepts native
   pressed/open_requested; partial/unconfigured shortcuts/focus/mouse suppressed without sibling
   consumption. Native disabled/loading remains authoritative. Coach highlighted inherited pulse/ring.
3. Filling completion pops icon FAST/SPRING; pulse_already()->Error twice1.06FAST/IN_OUT root pulse.
   Tokens.Action.ALREADY_SCALE transcribes existing DESIGN1.06; classify it unitless in the CSS generator and existing token completeness oracle and regenerate CSS only, no theme edits.
   Kill interrupted tweens and cancel already motion before native press/highlight motion. Reduced
   already feedback keeps a static translated Badge/outline until count/native interaction changes;
   reduction before/during removes motion/settles state. Exit kills work,
   re-entry preserves count/target/copy/native signals; layout/copy/theme/wrapping use catalog helpers.
4. HintButton retains old IconButton/P1 labelled behavior until configure(kind:hint|reveal,count:int,
   price:int)->Error succeeds. Atomic reject unknown kind/negative count/price. Read-only kind/count/
   price/catalog_mode. Final glyph lightbulb(hint)/sparkles(reveal), translated native name/tooltip;
   positive count shows Badge, zero count coin glyph + exact Numeric price. No affordability decision.
5. Final native pressed emits activated(kind); caller owns business work and disabled. Inherited
   normal/pressed/disabled/loading/highlighted states and native keyboard/shortcut/focus retained.
   Configure while loading updates saved final glyph but preserves spinner/loading/disabled; completion
   restores current glyph. set_amounts(count,price,animate=true)->Error validates atomically and count
   change may pop Badge FAST/SPRING. Count and price remain visible with static cue during reduction.
6. Caller-owned translations and footer layout/minimum growth survive locale/theme/resize/re-entry;
   exit cancels count/pop work and owned signal connections. Static keys in ui.csv; dynamic integers
   avoid plural sentences. No screen/Nav/service/economy/config/save/project/export wiring.
7. Powerups gallery scrolls normal/filling/full/already/highlighted BonusMeter with replay controls;
   both Hint kinds count/price/disabled/loading/highlighted and legacy prototype. Native review matrix,
   smoke and old P1 tests unchanged. Full native press/atomic/motion/lifecycle tests.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1/2 catalog only; R-UI-3 token/theme visuals/motion; R-UI-4 static locale keys; R-UI-5 generated
themes untouched (generated CSS token regeneration only); R-UI-6 native3classes xPL/PSEUDO
xdefault100/HC130 captures. Device/screen-reader/taste/Opus gates remain open.

## Tests
- Bonus integer config/invalid atomic/over-target/normalized progress, native partial/full intent,
  focus/disabled/shortcuts/sibling suppression, exact ratio and full gift/Open/check cues.
- Interrupted fill/pop/already/replay, reduction before/during, finite durations/endpoints,
  exit/re-entry/locale/theme and gallery wrapping/fit/scroll.
- Hint old P1 tests unchanged (token completeness ratio declaration gains the new scale only) and legacy behavior, final kind/count/price/icon/a11y, invalid atomic,
  native pointer/key/disabled/loading/highlighted, configure while loading restores latest glyph,
  count pop interruption/reduction/exit, locale/theme/footer minimum/re-entry/owned translations.
- Full make check, scope/task lint, independent fresh review and final-head13CI controls then merge.

## Out of scope
Economy balance/rewards/availability rules, new config/service APIs, screen integration, physical
certification, platform/project/export/save/content/ROADMAP and generated theme edits.
