---
id: T-0493
title: Open the ranked campaign on a map of floating islands
epic: E14
type: feat
area: features.home
risk: medium
executor: sol
think: high
ui: med
status: review
depends_on: [T-0492]
touch:
  - game/services/content/campaign_islands.gd*
  - game/services/nav.gd
  - game/services/nav/offline_campaign.gd
  - game/services/nav/p2_navigation.gd
  - game/features/home/island_home.gd*
  - game/features/level/p2_hud.gd
  - game/locale/home.csv
  - game/ui/tokens.gd
  - tools/export_smoke.gd
  - docs/qa/T-0493/**
revision: 1
---

## Goal

Start the ranked Polish QA campaign on a map of four floating islands. Change the landscape on every consecutive level and keep each island's theme consistent.

## Context

- The requested first-launch map extends the QA flow described in T-0492. Standard boot and Journey unlocks follow `DESIGN.md#screen-map-and-ux-flows`.
- R-UI-1 says “A screen task may not create a component.” R-UI-2 assigns any new component its own task.
- R-UI-3 says “Use `Tokens.*`, theme type variations or theme constants.” R-UI-4 assigns visible copy to translation keys.
- R-UI-5 says “Never edit `game/ui/theme/generated/`. Change `tokens.gd`, rerun the generator.” R-UI-6 requires screenshots.

## Behavior

- Load optional debug art for the exact ranked manifest. Validate the ordered ranges and their textures before using the map. Use standard screens with no matching map.
- Make Home show the map on the first launch and when resuming. Show the four names, the active island and the slots that open later islands. Play opens the same committed level that the campaign would otherwise resume.
- Provide a return to the map from the first live Level. Preserve Settings and the existing Journey unlock. Route slots and completion still use the same campaign and save owners.
- Select a background by offset within its island. Repeat three locally bundled views in order and start a new sequence at the next island. Preserve high contrast on the play screen and respect it on the map.

## Verification

- Boot the exported ranked APK resource pack with a fresh profile. Open Level 1, solve it by touch, continue to Level 2, and return to the map. Check Settings and verify saved progress on a new launch. Check the island boundaries with the exported content.
- Run `make check` with standard content and the task scope check. Capture the map and consecutive Level views from the ranked QA export. Keep the staged assets in the QA directory for the debug build.
