---
id: T-0494
title: Break the ranked campaign into shorter islands
epic: E14
type: feat
area: features.home
risk: medium
executor: sol
think: med
ui: med
status: review
depends_on: [T-0493]
touch:
  - game/features/home/island_home.gd
  - game/services/content/campaign_islands.gd
  - game/locale/home.csv
  - docs/qa/T-0493/README.md
  - docs/qa/T-0493/verify.gd
  - docs/qa/T-0493/art/islands.json
  - docs/qa/T-0494/**
revision: 1
---

## Goal

Split the ranked 10,000-level QA campaign into journeys of 25 levels through level 100 and 50 levels thereafter. Keep the existing artwork and change the view at every consecutive level.

## Context

- T-0493 supplies the map, the saved-slot route and four illustrated themes.
- R-UI-1 says “A screen task may not create a component.” R-UI-2 assigns new components their own task.
- R-UI-3 says “Use `Tokens.*`, theme type variations or theme constants.” R-UI-4 assigns visible text to translation keys.
- R-UI-5 says “Never edit `game/ui/theme/generated/`.” R-UI-6 requires screenshots.

## Behavior

- Build contiguous islands from the configured opening endpoints and repeat an equal span until the last slot. Slot 100 remains on the fourth island, and 101 opens the fifth.
- Reuse the four existing themes in sequence. Adjacent levels always select different artwork, and opening a known slot selects its corresponding view.
- Show four islands per page. Open the saved slot's page and display each island's complete range. Keep Play tied to the saved slot.

## Verification

Check all 10,000 slot assignments and art transitions in the exported QA pack. Exercise the first, second and last page plus saving and restarting. Run stock regression and task scope checks. Capture desktop renders in the regular, compact and tablet layouts.
