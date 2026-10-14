---
id: T-0244
title: Compose the committed campaign Home screen
epic: E16
type: feat
area: features.home
risk: low
executor: cheap
think: med
ui: high
status: review
depends_on: [T-0243, T-0220]
touch:
  - game/features/home/**
  - game/services/nav.gd
  - game/locale/home.csv*
  - game/tests/integration/test_home_screen.gd*
  - docs/qa/T-0244-home-screen.md
  - docs/qa/T-0244/**
  - tasks/T-0220-reward-postcard.md
  - tasks/T-0244-home-screen.md
revision: 1
---

## Goal
Implement roadmap T-0244 / FR-META-05: Home presents the current location, persisted postcard
pieces, next campaign slot and one Play action, using existing catalog components.

## Context
- `docs/DESIGN.md#home`: "PrimaryButton(text: home.main.play, sublabel: home.main.level_n)".
- `docs/DESIGN.md#flow-returning-user`: "Play on Home always continues the next campaign slot".
- `docs/DESIGN.md#navtab`: "Tabs for unbuilt features are hidden, not locked."
- `docs/GAME_DESIGN.md#postcards`: "Revealed pieces and completed postcards are never taken away".
- Reference: `docs/design/T-0205/README.md` Home mockup; `docs/DESIGN.md#pr-screenshot-rules`.

## Current state
Fresh main aac79fa has merged T-0243 (done) and T-0220 (merged, status still review; reconcile
only that stale status). Home files and home.csv do not exist. Nav.SCENES already maps HOME to
res://features/home/home.tscn; _enter currently injects only Level/Debug. Nav.go_to_level(slot),
go_to_screen(Screen), transition_finished and enqueue_toast(key,variant) exist.
Save.committed_view() returns copied error/sections with settings.language, economy.coins and
progress.by_lang[language].current_slot/location_pieces. Content.location_for_slot(slot) returns
copied metadata with id/name_key/postcard; legacy campaign metadata has an empty name/art path.
Config has_key/get_int includes meta.postcard.pieces. Global P2 Progress/Economy are intentionally
not automatically activated by boot; this task must not activate them or infer any rewards.
ScreenScaffold.body/top_bar/bottom, TopBar.configure, CurrencyPill.value/action_enabled,
IconButton.configure_icon, LocationPostcard.configure, PrimaryButton.text_key/sublabel_key,
NavTab.configure/implemented and StatePanel.configure exist. LocaleCatalog owns imported copies.
PrimaryButton sublabel accepts a translation key, not formatting arguments. Screen-owned unique
translation messages may bind the formatted home.main.level_n template without component edits
or accessing component-private fields. No production postcard textures are shipped yet.

## Specification
1. Add HomeScreen extending ScreenScaffold and a minimal themed home.tscn. Expose
   configure(save:Node,content:Node,config:Node,nav:Node,art_loader:Callable=Callable())->void
   before mounting and refresh()->Error. Nav injects its actual owners into HOME before add_child,
   preserving test factories, P1 routing and existing Level/Debug behavior.
2. Read one Save committed snapshot; reject unloaded/error/mismatched content language safely.
   Display the committed wallet, actual next slot and location metadata; never dirty staged values.
   No grant/spend/progression/flush writes. Use configured piece total and persisted pieces only;
   clamp presentation counts to valid component bounds without modifying save. Completed postcard
   presentation comes from saved pieces or the saved completed-postcards marker, never inferred
   from campaign completion or star division; a completed marker remains complete after rebalance.
3. Layout matches Home reference: coin pill and settings icon in TopBar; title, full LocationPostcard
   and one Play button in centred body with Space.L; Journey NavTab in bottom when its scene exists.
   Daily/Collection are absent in P2. Coin pill is passive until Shop exists; Settings is disabled until
   its scene exists. Available Settings/Journey call only Nav.go_to_screen. No empty-screen buttons.
4. Play rereads the committed current slot before calling Nav.go_to_level; never routes a historical
   displayed slot or clamps an exhausted campaign back to its last level. Out-of-range/missing level
   disables Play and shows existing StatePanel(error). Successful routes block duplicate input on the
   outgoing screen; failed/busy routes retain Home and restore input, with an inline translated error.
5. Missing legacy names use home.main.title. Resolve authored postcard paths under res://assets/;
   optional injected loader permits fixture textures. Missing/corrupt art shows StatePanel(empty),
   keeps the actual location title and a translated pieces count, and leaves valid Play usable.
   Data errors disable Play and keep an explanatory StatePanel. No synthetic production location/art.
6. Bind the next slot into the Play sublabel using screen-owned per-instance translation keys copied
   from raw PL/EN home.main.level_n templates (so pseudo applies once). Dispose owned translations
   and manually connected signals on exit. Labels refresh on translation change; component theme,
   motion, safe-area and accessibility behavior remain owned by the existing components.
7. Home uses the Nav-owned Toast unchanged: backup results drain after Home mounts, including its
   theme/safe body. No screen-created Toast, popup, provider call, coach mark or analytics event.

## UX rules (quoted)
- **R-UI-1** A screen task may not create a component. If a needed component or state is missing, STOP (S4) and request a separate `ui.components` task.
- **R-UI-2** New component = separate task (`area: ui.components`), including its gallery entry.
- **R-UI-3** No raw numbers in scenes or feature scripts: no literal colours, font sizes, margins, radii or durations in `game/features/**` or `game/ui/components/**`. Use `Tokens.*`, theme type variations or theme constants. Allowed literals: `0`, `1`, `-1`, array indices, and ratios defined in `Layout.*`. (Candidate CI check: `tools/check_tokens.py` greps for `Color(`, `#rrggbb`, numeric `tween_property` durations outside `game/ui/tokens.gd`.)
- **R-UI-4** Strings shown to players use translation keys (`#copy-and-tone`), never literals.
- **R-UI-5** Never edit `game/ui/theme/generated/`. Change `tokens.gd`, rerun the generator.
- **R-UI-6** Every UI PR with `UI: med|high` attaches screenshots per `#pr-screenshot-rules`.
Use existing scene/label/layout primitives only, Space.L and theme Title/Caption variations.
Capture COMPACT/REGULAR/TABLET in PL/PSEUDO and HC130, including missing-art state. Any fixture art
must be labelled QA-only. Chris supplies physical device/taste/PL approval before UI acceptance.

## Tests
New game/tests/integration/test_home_screen.gd, isolated SaveStorage + deterministic Clock:
- committed slot 2/coins 240/pieces 2 of 4: injected Home shows exact values, one primary Play,
  synthetic fixture location title and correct postcard state; rendering does not change save.
- dirty staged coins/slot/pieces: refresh still shows prior committed values until durable flush.
- Play reads a newer committed slot; records one request with that slot; no historical/last-level replay.
- route ERR_BUSY: Home stays mounted and Play is available for retry; successful route suppresses repeat.
- terminal slot 4 for a 3-slot campaign and corrupt/unavailable content: disabled Play, explanatory state.
- legacy/missing art: generic title or actual authored title, pieces caption, usable Play, no fake art.
- unbuilt Journey/Daily/Collection hidden, Settings disabled, currency passive; built route intent only.
- PL/EN/PSEUDO sublabel includes exact slot; mounting independent Homes does not overwrite their keys;
  exit removes screen-owned messages and preserves other owners' translations.
- real Nav mounts Home at threshold using its injected services, plays back into the actual Level,
  and pending backup Toast inherits Home theme/bounds; existing navigation tests remain unchanged.
- safe insets COMPACT/REGULAR/TABLET and HC130/PSEUDO: controls fit safe body and labels are untruncated.
Run full make check, task/scope checks, clean import and all CI checks. Existing tests unchanged.

## Out of scope
Journey/Settings/Shop content, daily/collection, onboarding, production art/locations, provider SDKs,
atomic gameplay activation, save/economy/config/content/analytics changes, new components/tokens,
autoloads, project/export settings and roadmap edits.

## Acceptance
All listed behaviors/tests pass, screenshots attached beside the Home reference. Full make check
and CI green. The task remains review until Chris accepts UI/device evidence; no automatic merge.
