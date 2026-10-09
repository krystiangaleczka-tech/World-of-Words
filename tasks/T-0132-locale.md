---
id: T-0132
title: Register per-area locale translations before the first screen
epic: E09
type: infra
area: locale
risk: low
executor: sol
think: low
ui: low
status: done
depends_on: [T-0043, T-0048, T-0116]
touch:
 - game/services/locale/locale_catalog.gd*
 - game/services/nav/boot.gd
 - game/services/nav.gd
 - game/locale/debug.csv
 - game/locale/debug.csv.import
 - game/tests/integration/test_locale_catalog.gd*
 - game/tests/integration/test_debug_screen.gd
 - docs/qa/T-0132-locale.md
 - tasks/T-0132-locale.md
revision: 1
---

## Goal
Automatically register every imported per-area CSV translation before P1 screens
mount, with English keys and Polish copy. New areas need no project.godot edits.

## Current state
T-0043/T-0048/T-0116 are done. T-0051 has no task file and its human phase exit
is not claimed. Chris's current next-five request continues the already authorized
prototype work, using actual technical dependencies as T-0120 does; ROADMAP is
unchanged. game/locale/level.csv and debug.csv use keys,pl,en headers and
English area.screen.element keys. Godot 4.7.2 imports them into locale/*.translation
resources. ResourceLoader.list_directory exists and discovers resource paths in
editor and exported PCK. LevelCopy and Debug independently own translations for
standalone screens. Boot calls Nav.boot then Nav.start; Nav.start reads saved
language before manifest load but currently does not set TranslationServer locale.
Root NOTICE and generated PL content exist. No platform export presets exist yet.

## Specification
1. Add typed non-autoload LocaleCatalog, owned by boot. Discover imported
   .translation resources dynamically via export-aware ResourceLoader directory
   listing. CSV source files need not exist in exported packs. Load/validate all
   resources before registering any; return Error on missing/empty directory or
   invalid translation resource. Duplicate resources for independent ownership.
   Register idempotently, unregister only owned copies, permit retry after failure.
2. Boot registers the catalogue before Nav.start and releases it on exit. Failed
   registration stops before screens and uses internal diagnostics. No per-file
   preloads, project.godot entries, new globals or dependencies.
3. Explicitly set TranslationServer locale from the saved language after successful
   content load and before the first screen mounts in Nav.start. Preserve public
   signatures, save format and navigation states; no locale change on failed boot.
4. Keep existing per-screen translation ownership for standalone tests/tools.
   Correct Debug Polish Home to Menu and Wersja contentu to Wersja poziomów, retaining
   existing English keys/values. Current Level copy stays unchanged. Verify CSV
   keys match each area, are unique, and have nonempty PL/EN values.

## UI rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1 A screen task may not create a component. Missing component/state stops S4.
- R-UI-2 New component = separate ui.components task including gallery entry.
- R-UI-3 No literal colours, font sizes, margins, radii or durations in features/UI
  components; use tokens/theme. Allowed literals: 0,1,-1,indices,Layout ratios.
- R-UI-4 Strings shown to players use translation keys, never literals.
- R-UI-5 Never edit generated theme; change tokens and rerun generator.
- R-UI-6 UI med/high PRs attach screenshots per DESIGN.md#pr-screenshot-rules.
No components, visuals or layout change. Copy stays short, neutral and free of
plural-dependent sentences. Native-speaker/device acceptance is not claimed.

## Tests
New integration tests: imported new area discovers PL/EN with no project entries,
actual areas translate, registration idempotence, other-owner preservation,
invalid resource causes no partial registration and can retry, CSV conventions,
real boot registers before first screen and sets saved PL despite previous EN
locale, and exit releases catalogue. Update only the two authorized Debug copy
assertions. Missing/empty directory and failed Nav boot preserve locale tests.
Read-only temporary PCK probe verifies compiled translations without raw CSV.
Full make check, task/scope lint, fresh independent review and all CI.

## Acceptance
All tests green; automatic catalogue, startup locale and current P1 PL keys work.
No project/export settings, save/schema/economy changes or manual device claim.

## Rollback
Revert catalogue, boot/navigation locale calls and copy changes together. Existing
per-screen ownership continues to support standalone screens.

## Escalation resolution
S1: the initially authored dependency T-0051 was absent, and task lint rejected it.
The initial claim that it was done was incorrect. No phase gate is closed or human
evidence invented. The current explicit next-five instruction, following the
authorized prototype continuation recorded in docs/qa/P1-authorized-wave.md and
T-0120, authorizes this bounded P1 implementation. This new specification names
actual done Nav/Debug/Level dependencies before its first commit; no existing
contract or ROADMAP row is rewritten and no repeated permission is requested.
