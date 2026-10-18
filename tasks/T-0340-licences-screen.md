---
id: T-0340
title: Browse complete offline licences in a catalog screen
epic: E21
type: feat
area: features.settings
risk: medium
executor: sol
think: med
ui: high
status: review
depends_on: [T-0339, T-0285]
touch:
  - game/features/settings/licences*
  - game/locale/settings.csv*
  - game/tests/integration/test_licences_screen.gd*
  - docs/qa/T-0340/**
  - docs/contracts/settings.md
  - tasks/epics/E21-settings.md
  - tasks/T-0340-licences-screen.md
revision: 1
---

## Goal
Show all T-0339 notices offline through a readable, scrollable licences screen.
This is the screen portion split from ROADMAP T-0288 under Phase-2 rolling-wave
planning. Its store/consent/privacy/support integrations remain separate.

## Context
- docs/PRODUCT.md#fr-set-settings — FR-SET-03: licences/credits including engine,
  third-party, asset and dictionary/frequency notices.
- docs/DESIGN.md#settings — Settings.about.licences opens a licences screen.
- docs/contracts/settings.md — catalog and existing explicit Settings action intent.

## Current state
SettingsCredits.entries() supplies seven fresh id/notice dictionaries. SettingsScreen
emits action_requested(licences); caller owns navigation. ScreenScaffold, TopBar,
IconButton, ListRow and CatalogSurface.label provide the existing catalog controls.
No licences screen exists. Boot/Nav does not yet activate Settings.

## Specification
- Add LicencesScreen extends ScreenScaffold and a minimal licences_screen.tscn.
  No new UI component or singleton. Index has seven catalog ListRows with translated
  labels and chevrons. A single vertical ScrollContainer switches between index
  and a plain wrapped Body Label containing the exact selected legal notice.
- Expose select_notice(id:StringName)->Error, handle_back()->void and back_requested.
  Selecting before mount fails unconfigured; unknown IDs fail without mutation.
  Selection starts notice scroll at top. Back from notice returns to index, restoring
  prior list scroll/focus; Back from index emits exit intent once. Retained reentry
  preserves the selected notice and reconnects no duplicate callbacks.
- Keep notices verbatim, untranslated and without BBCode/link interpretation, even
  in pseudolocalization. Only navigation and source labels translate PL/EN. Live
  language/theme changes update labels and the existing generated theme. Long URLs
  wrap; no horizontal scrolling/truncation or raw visual numbers.
- Caller routes existing Settings action_requested(licences) to this scene and
  back_requested to its own navigation; no boot/Nav or provider changes. Verify this
  explicit composition in integration tests. Do not fabricate native SDK notices.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1: A screen task may not create a component. Use existing catalog only.
R-UI-2: New component = separate task; none is introduced.
R-UI-3: No raw visual numbers; use Tokens and theme variations.
R-UI-4: Player copy uses translation keys; legal notices remain original data.
R-UI-5: Never edit generated themes.
R-UI-6: Attach native three-class PL/PSEUDO default100/HC130 screenshots.

## Tests
New GUT suite verifies exact seven index choices and all notices, pre-mount/unknown
selection, two-stage Back, actual Settings intent routing, keyboard activation,
retained reentry, unchanged legal data on live translation, and a 12-case native
layout matrix: 3 classes x PL/PSEUDO x default100/HC130. Check touch targets,
TopBar fit, no horizontal overflow, long notice scroll to end and index restoration.
With WOW_LICENCES_CAPTURE_DIR set under native X11, save actual viewport images of
index and content notice top/bottom for every case. Headless runs geometry without
claiming rendered evidence. Full make check, independent review and all CI green.

## Acceptance
Full exact legal data is browseable offline; native evidence covers 36 images and
is inspected. Device/taste review and global Settings boot/Nav activation remain
open. No new SDK, endpoint, export, save, economy or analytics changes.
