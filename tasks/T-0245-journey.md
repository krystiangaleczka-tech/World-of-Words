---
id: T-0245
title: Show one-region Journey and completed campaign progress
epic: E16
type: feat
area: features.journey
risk: low
executor: sol
think: med
ui: high
status: review
depends_on: [T-0244]
touch:
  - game/features/journey/journey.gd*
  - game/features/journey/journey.tscn
  - game/services/nav.gd
  - game/locale/journey.csv*
  - game/tests/integration/test_journey.gd*
  - game/tests/integration/test_home.gd
  - game/tests/fixtures/journey/**
  - docs/qa/T-0245/**
  - tasks/T-0244-home.md
  - tasks/T-0245-journey.md
revision: 1
---

## Goal
Implement roadmap T-0245: Home opens a scrollable Journey showing one current region and its
locations. Completed campaign levels are informational only, never replayable (FR-PROG-06).

## Context
- PRODUCT.md FR-META-04: "Journey screen shows regions and locations with locked / in progress / complete states."
- DESIGN.md#journey-1-region: back, region title, stars, scrolling Cards with postcard thumbnails,
  piece progress, locked/current/complete cues; no next-region teaser in P2.
- Reference: docs/design/T-0205/evidence/journey_COMPACT_PL_default.png.

## Current state
Main 6d82944 merged T-0244; reconcile its review status to done. Home automatically shows its
Journey NavTab when res://features/journey/journey.tscn exists. Nav Screen.JOURNEY exists but has
no scene mapping; HOME injection supplies Save, Content, Config and Nav before mounting.
Save.committed_view().sections.progress.by_lang carries current_slot/highest_completed_slot,
stars and location_pieces. Content exposes region_for_slot, location_for_slot, slot_count and
get_language; legacy metadata is a virtual campaign region/location without art. Config exposes
meta.postcard.pieces. ScreenScaffold, TopBar, CurrencyPill, IconButton, Card.configure_body,
LocationPostcard, CatalogProgressBar, Badge, StatePanel and LocaleCatalog exist.
Card's passive body is caller-owned and detached on exit; the screen must dispose it explicitly.
Global Progress P2 remains deliberately inactive; no owner/provider activation in a screen task.

## Specification
1. Add Journey scene/script extending ScreenScaffold. Map Screen.JOURNEY and inject the same
   Save/Content/Config/Nav identities as Home. Back calls the guarded Nav.handle_back. Home's
   existing tab now opens this actual scene; update only its old unavailable-tab assertion and
   add real route/back assertions in test_home.gd, retaining the other existing assertions.
2. Read only committed_view. Select the region containing current_slot (terminal uses last shipped
   slot only for metadata lookup); show only that region, traversing its validated location ranges
   without loading campaign packs. Title uses metadata name_key, legacy fallback journey.main.title.
   Stars pill is passive and shows persisted stars. If a long region title cannot fit the header,
   show it as a wrapped Title label beneath the bar rather than dropping/truncating it. Never write Save or derive reward balances.
3. Each location Card has metadata title (fallback journey.location.title), thumb LocationPostcard
   when art exists, piece ProgressBar and numeric pieces/total caption. Use configured postcard
   count and persisted credits, clamped for presentation; no inferred or awarded pieces. Resolve
   art relative to res://content/<language>, with an optional injected resolver for previews/tests.
   Missing art uses translated caption; no fake shipped artwork.
4. Campaign state: locked when current_slot < first, complete when highest_completed_slot >= last,
   otherwise current. Locked cards disabled, passive lock Badge and formatted unlock-slot caption;
   current highlighted with explicit state copy, complete with explicit completion copy. Show
   completed level range and count using durable highest_completed_slot, never level buttons or
   any go_to_level call. Postcard progress remains independent of campaign completion.
5. Region completion has a translated summary. No second-region teaser, replay, economy writes,
   popups or automatic grants. Current cards remain passive with an explanatory postcard-coming
   caption until T-0246 implements the postcard destination and selection context; do not navigate
   to today's missing/empty POSTCARD scene. That temporary staged-integration concern is explicit
   in the PR, matching Home's prior handling of not-yet-implemented Journey.
6. Missing/unloaded Save/Content/Config, language mismatch or unavailable committed view clears
   old rows and shows translated StatePanel; Back remains usable. Config piece capacity outside
   LocationPostcard's supported range also yields unavailable, never misleading zero progress.
7. Owned locale registration, row bodies and nodes clean up on refresh/exit/re-entry. Translation
   notifications update formatted captions without resetting scroll/history. Layout uses token
   spacing, wrapping and safe-area ScrollContainer; no horizontal overflow with HC130/PSEUDO35%.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: "A screen task may not create a component."
- R-UI-2: "New component = separate task" including gallery.
- R-UI-3: "No raw numbers in scenes or feature scripts"; tokens/theme only.
- R-UI-4: "Strings shown to players use translation keys".
- R-UI-5: "Never edit game/ui/theme/generated/".
- R-UI-6: "Every UI PR with UI: med|high attaches screenshots" per screenshot rules.
Compose only the existing catalog and basic scene containers. Native COMPACT/REGULAR/TABLET x
PL/PSEUDO (GalleryShell.OPTIONS, 35% expansion) x default100/HC130 screenshots plus missing-art
and complete-region states. Chris owns reference-device screenshots and taste approval; pending.

## Tests
New test_journey.gd: real Home/Journey/Back injection; three locations complete/current/locked;
completed ranges/counts without replay; committed stars/pieces ignore pending writes and no file
writes; independent campaign/postcard completion; correct current-region and terminal selection;
legacy/missing art and optional art resolver; missing/unloaded services and language mismatch;
refresh/exit/re-entry cleanup, translation update; all three safe layouts with HC130/PSEUDO35%,
no horizontal overflow and last location reachable by scroll. Test-only metadata catalog fixture,
no edits to generated content. Existing Home test changes limited to implemented Journey behavior.
Full make check, scope/task lint, independent exact-head review and all14CI before merge.

## Out of scope
T-0246 postcard screen/selection/navigation, final art/location copy, region production content,
gameplay/economy/provider activation, Save/Content schemas, components/themes, project/export,
roadmap changes and physical-device certification.
