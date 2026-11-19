---
id: T-0492
title: Preview illustrated backgrounds during the Polish campaign
epic: E14
type: feat
area: level.flow
risk: medium
executor: sol
think: med
ui: med
status: review
depends_on: [T-0205, T-0212, T-0398]
touch:
  - game/features/level/campaign_background.gd*
  - game/features/level/level.gd
  - game/ui/components/ScreenScaffold.gd
  - game/ui/tokens.gd
  - game/tests/integration/test_scaffold_topbar.gd
  - docs/qa/T-0492/**
revision: 1
---

## Goal

Show four Ceramic-style landscapes while playing the ranked 10,000-level QA campaign.

## Current state

- Level uses `ScreenScaffold`, which already accepts a decorative texture above its theme fill.
- The ranked QA campaign resolves to the existing single virtual location. Its manifest has no postcard paths.
- Home already resolves bundled postcards from the loaded language's content directory.

## Specification

- Give Level the bundled postcard for the current slot when one exists. Apply the Level artwork opacity token, and show the theme fill in high contrast.
- Support an optional debug catalog for the exact ranked QA manifest. Mount the matched texture behind the existing grid and wheel. Keep the standard fill when the texture cannot load.
- Keep the four preview files in QA and stage them in the disposable Android checkout. The QA catalog does not modify the campaign content or location progress.
- Apply `DESIGN.md` R-UI-1 to R-UI-6 using the existing scaffold and an opacity token. Capture the actual Level in the three layout classes.

## Tests

- Check that translucent art ignores input and returns after switching back from high contrast. Check the plain fallback.
- Load actual levels in the exported ranked build and verify each of the four illustrations, including the slot on either side of each transition. Verify the rendered board and the normal wheel flow.

## Acceptance

`make check` and the task scope check pass. Deliver the signed QA APK and runtime screenshots. Assemble production postcard art under T-0308/T-0309 after the existing Q14 decision.
