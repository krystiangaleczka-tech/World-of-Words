---
id: T-0244
title: Compose returning-player Home from committed progress
epic: E16
type: feat
area: features.home
risk: low
executor: sol
think: med
ui: high
status: review
depends_on: [T-0243, T-0220]
touch:
  - game/features/home/**
  - game/services/nav.gd
  - game/locale/home.csv*
  - game/tests/integration/test_home.gd*
  - docs/qa/T-0244/**
  - tasks/T-0220-reward-postcard.md
  - tasks/T-0244-home.md
revision: 1
---

## Goal
Implement roadmap T-0244 / FR-META-05: Home presents current location, durable postcard progress,
next campaign slot and one Play action. Reconcile the already merged T-0220 prerequisite.

## Context
- DESIGN.md#home: current location title, full LocationPostcard, one primary Play, coins/settings.
- DESIGN.md#flow-returning-user: "Play on Home always continues the next campaign slot".
- Reference: docs/design/T-0205/evidence/home_TABLET_PL_default.png and DESIGN.md#home.

## Current state
Main aac79fa merged T-0243; Nav lazily mounts res://features/home/home.tscn (currently absent),
provides guarded go_to_level/go_to_screen and owns pending Toasts. Save.committed_view returns
sections with economy.coins and progress.by_lang[language].current_slot/location_pieces.
Content.location_for_slot returns name_key, postcard resource path and pieces; the shipped legacy
manifest has virtual campaign metadata with no art. Content.get_language and slot_count exist.
Config.get_int(meta.postcard.pieces) is available. ScreenScaffold, TopBar, CurrencyPill,
IconButton, PrimaryButton, NavTab, LocationPostcard, StatePanel and LocaleCatalog exist.
Global Progress P2 is deliberately not activated by Nav; do not activate it here.

## Specification
1. Add Home scene/script extending ScreenScaffold. Nav injects its actual Save/Content/Config and
   navigation owner before mounting; independently mounted previews default to autoloads.
2. Read only committed_view on mount and refresh. Select saved language, current_slot without
   clamping Play to a completed level; use last shipped slot for terminal location display only.
   Show committed coins and persisted location_pieces (clamped to rendering capacity). No grants,
   writes, migration, gameplay-provider activation or inferred stars/pieces.
3. Use metadata name_key, otherwise home.main.location. Load postcard relative to
   res://content/<content-language>/ using ResourceLoader only when it exists. Allow an injected
   art resolver for deterministic previews/tests. Valid art configures full LocationPostcard and
   scaffold background. Missing art uses StatePanel and a translated progress caption; no fake
   final artwork. Missing services/content/save disables Play with explanatory copy.
4. One PrimaryButton Play with adjacent formatted next-level caption (existing ActionButton has
   no parameterized-sublabel API). Play re-reads committed state, routes exact current slot,
   preserves partial-board restoration through existing Level, reports route failure inline.
   Terminal slot disables Play and explains content is complete; no replay of the last level.
5. TopBar shows passive coins and settings IconButton. Settings is disabled with translated
   unavailable tooltip until its scene exists. Journey NavTab routes JOURNEY when its scene
   exists; hide it before T-0245. Daily/Collection remain hidden P3 features. No empty-screen links.
6. Body uses Space.L, vertical expandable ScrollContainer for large text; bottom remains safe.
   Compose content on a token/theme PanelContainer surface so unknown artwork cannot reduce text
   contrast; this is scene composition using CatalogSurface.panel, not a new reusable component.
   Title/captions wrap. LocaleCatalog registration, translation notifications and exit/re-entry
   preserve correct copy and disconnect owned registrations. Refresh does not write Save.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: "A screen task may not create a component."
- R-UI-2: "New component = separate task" including gallery.
- R-UI-3: "No raw numbers in scenes or feature scripts"; use tokens/theme.
- R-UI-4: "Strings shown to players use translation keys".
- R-UI-5: "Never edit game/ui/theme/generated/".
- R-UI-6: "Every UI PR with UI: med|high attaches screenshots" per screenshot rules.
Native COMPACT/REGULAR/TABLET, PL/PSEUDO, default100/HC130 captures plus mockup reference;
Chris owns reference-device screenshots and taste approval, recorded as pending rather than fabricated.

## Tests
New test_home.gd: injected-service boot/mount; committed coins/location/pieces/slot and no writes;
partial saved board resumes through actual Level; failed navigation preserves Home and explains;
terminal slot never replays; invalid services (including Config alone missing/unloaded)/missing art graceful; configured art partial/complete;
locale changes/re-entry; future tab visibility; 3 layout classes with HC130/PSEUDO and fake insets,
no horizontal overflow and primary action reachable by scroll. Existing tests unchanged.
Full make check, task/scope lint, fresh independent exact-head review, all14CI before merge.

## Out of scope
Journey/Postcard content, artwork production, providers/economy/Progress activation, save/content
schemas, project/export configuration, roadmap edits, reference-device certification.

## Acceptance
All automated checks and native evidence pass. Review Home against the cited screen spec/mockup;
missing shipped art and not-yet-implemented destinations remain explicitly documented limitations.
