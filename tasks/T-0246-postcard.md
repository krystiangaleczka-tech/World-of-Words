---
id: T-0246
title: Present selected location postcards and durable reveal feedback
epic: E16
type: feat
area: features.journey
risk: low
executor: sol
think: med
ui: high
status: review
depends_on: [T-0245]
touch:
  - game/features/journey/postcard.gd*
  - game/features/journey/postcard.tscn
  - game/features/journey/journey.gd
  - game/features/level/level.gd
  - game/services/nav.gd
  - game/services/nav/p2_navigation.gd
  - game/locale/postcard.csv*
  - game/tests/integration/test_postcard.gd*
  - game/tests/integration/test_journey.gd
  - docs/qa/T-0246/**
  - tasks/T-0245-journey.md
  - tasks/T-0246-postcard.md
revision: 1
---

## Goal
Implement roadmap T-0246 / DESIGN.md#location-postcard: selected full postcard, name/fact,
complete stamp, committed newest-piece reveal feedback, Back and campaign Continue.

## Context
- DESIGN.md#location-postcard: full LocationPostcard; TITLE name; BODY fact; one Continue;
  revealing uses newest piece + RewardBurst(postcard_piece), complete has stamp/caption.
- PRODUCT FR-META-02/03: postcard pieces follow durable progression; presentation grants nothing.
- PRODUCT FR-PROG-06: completed campaign levels cannot be replayed.
- DESIGN.md#flow-level-complete: completed postcard may precede the next campaign level.
- Screen reference: DESIGN.md#location-postcard; existing postcard component gallery T-0220.

## Current state
Main 13958a8 merged T-0245. Nav Screen.POSTCARD exists but has no scene mapping or selection.
P2Navigation history stores screen+slot; route accepts screen/slot/remember and calls _mount_p2.
Journey has caller-owned passive Card bodies, locked/current/complete, with temporary coming-soon
copy. Card supports a separate footer action; use it rather than making touch-scrolling cards
capture pointer drags. Save.committed_view exposes progress.by_lang[language] current_slot,
highest_completed_slot, stars, location_pieces. Content.location_for_slot supplies id/name_key/
first/last/postcard; it has no fact field. Legacy shipped content has no art or location copy.
LevelScreen owns local P1 Progress, prepares persistence before leaving, and its Continue calls
Nav.go_to_level(slot+1); no atomic gameplay activation. LocationPostcard supports configure,
reveal_next, full/thumbnail and complete stamp. RewardBurst is presentation-only. LocaleCatalog,
ScreenScaffold, StatePanel, PrimaryButton and CurrencyPill exist. Verify these before implementation.

## Specification
1. Map POSTCARD to a new ScreenScaffold scene. Public Nav.go_to_postcard(slot:int,
   reveal_latest:bool=false)->Error routes a location containing that slot, canonicalized to its
   first slot. Reuse route/history slot as selected location context; no persistent selection or
   new singleton. Guard validation/selection under route busy state. Validate committed language,
   loaded services/content and Home unlock; reject locked/missing locations without screen/history
   changes. Generic go_to_screen(POSTCARD) selects the current committed campaign location.
2. Pass selected slot and a one-shot reveal flag into the mounted postcard scene. History restores
   the selected location but never the reveal flag. Identical postcard destinations are inert;
   different locations on POSTCARD can navigate. Failure retains selection/history/mounted node.
   Back from a completion postcard whose prior screen was LEVEL goes Home, avoiding a completed
   board; Journey-origin Back returns Journey. Original P1 routes/tests stay compatible.
3. Journey uses Card's existing footer action for each unlocked/current/completed location to
   request its postcard; locked rows have no action. Preserve passive card/list touch scrolling.
   Replace coming-soon captions with translated action availability. Update only existing Journey
   assertions for this newly implemented action, retaining state/no-replay/gesture coverage.
4. Postcard reads committed values only: selected metadata title, stars, configured piece count,
   persisted location_pieces clamped for display. Resolve illustration below res://content/<lang>,
   optionally inject a texture resolver via configure_art(Callable) before mounting for preview/test. Show full LocationPostcard; missing art
   uses StatePanel plus numeric progress. Fact key is location.<id>.fact; missing translated copy
   has explicit fallback even with PSEUDO. No invented location facts, schema/art/content edits.
5. One Continue re-reads current committed slot and routes that exact playable campaign slot,
   restoring partial boards. Terminal content disables it with a translated explanation; never
   clamp terminal to the last level or use selected historical location as a gameplay destination.
   Missing/unloaded services, invalid piece capacity or language mismatch show unavailable state;
   Back remains available; route/persistence failures remain inline, no lost current screen.
6. With reveal_latest and actual persisted pieces >0, render count-1 then reveal_next once and
   play RewardBurst(postcard_piece,1) after the Nav transition settles (or preview layout is ready).
   Never increase stored credits or animate absent art. Complete stamp/caption follows the component
   settlement; reduced motion is immediate/static. Refresh, locale changes, re-entry and Back do
   not replay old feedback; exit cancels/disconnects owned work. Pending callbacks after exit are safe.
7. Add Nav.continue_campaign(completed_slot:int,previous_pieces:int)->Error and
   Nav.postcard_piece_count(slot:int)->int. Level records the location's committed credits at mount.
   Its successful completion Continue uses the new API when available; P1/fake Nav retains old
   go_to_level behavior. With an actual committed credit increase and Home unlocked, route through
   the completed location's revealing postcard, including a terminal completion. Otherwise follow
   existing chaining. Only compare persisted credits: no reward calculation/provider activation.
   APIs reject ineligible/uncommitted completion; failed leave preserves Level and allows retry.
8. Token-based scroll layout, safe insets, translated wrapping and semantic reading surface;
   native 3 layout classes x PL/PSEUDO35% x default100/HC130 captures, partial/complete/missing-art/
   terminal and normal/reduced reveal evidence. Device/taste approval remains Chris's pending gate.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: "A screen task may not create a component."
- R-UI-2: "New component = separate task" including gallery.
- R-UI-3: "No raw numbers in scenes or feature scripts"; tokens/theme only.
- R-UI-4: "Strings shown to players use translation keys".
- R-UI-5: "Never edit game/ui/theme/generated/".
- R-UI-6: "Every UI PR with UI: med|high attaches screenshots" per screenshot rules.
The bounded integration touches Nav/helper, Journey and Level plus the new screen/copy; no reusable
component. Real art/location facts remain separate content/copy work (T-0289).

## Tests
New test_postcard.gd: real Journey footer -> selected postcard -> Back; history selection and inert
same destination; locked/invalid/busy/failed-route guards preserve screen; current saved slot and
actual partial board resume; terminal no replay; committed stars/credits and no writes; missing
art/fact/config/content/language; reduced/normal newest-piece reveal and complete stamp, one-shot
refresh/re-entry/exit cleanup; actual Level Continue with externally committed credits routes
postcard, unchanged-credit chaining remains, terminal credit increase routes postcard; completion
Back goes Home; P1 compatibility. Native 3 safe layouts/HC130/PSEUDO35%, pointer scroll and Continue
reachable. Existing Journey assertion changes limited to new footer behavior; existing other tests
unchanged. Full make check, scope/task lint, independent exact-head review and all14CI before merge.

## Out of scope
Rewards or atomic gameplay activation, economy/save formats, SDKs, components/themes, final art/
facts, metadata schema/production packs, project/export/CI changes, roadmap and device certification.
