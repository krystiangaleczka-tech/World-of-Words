---
id: T-0326
title: Add a passive TutorialHand path animation and gallery preview
epic: E13
type: feat
area: ui.components
risk: low
executor: sol
think: med
ui: med
status: review
depends_on: [T-0220]
touch:
  - game/ui/components/TutorialHand.gd*
  - game/ui/gallery/tutorial.gd*
  - game/ui/gallery/tutorial.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/gallery.csv*
  - game/tests/integration/test_tutorial_hand.gd*
  - docs/qa/T-0326/**
  - tasks/T-0326-tutorial-hand.md
revision: 2
---

## Goal
Provide the catalog component needed by T-0291 without activating gameplay or
persisting tutorial state. Demonstrate playing/hidden/reduced states in Gallery.

## Context
Roadmap T-0326; PRODUCT FR-ONB-02; docs/DESIGN.md#tutorialhand-addition:
"ignores input", "static arrow along the path" for reduced motion.
Reference the accepted Level1 tutorial in docs/design/T-0205/README.md.

## Current state
TutorialHand does not exist. LetterWheelView.tile_position gives local tile centres;
hand.svg is already a pinned licensed Lucide icon. Tokens Motion.SLOW/BASE/FAST,
Ease.IN_OUT, Palette.TEXT and Elevation.MID exist. GalleryShell.PAGES special-cases Samples as a script; every other entry requires a
PackedScene. Add a minimal tutorial.tscn wrapper; actual catalog controls and gallery locale are available. No game wiring.

## Specification
- TutorialHand extends Control, passive IGNORE/no focus, drawing the existing hand
  icon at TEXT alpha0.85 with MID shadow. Caller mounts above wheel, below Toasts;
  caption belongs to caller and is never inside the hand.
- configure(points:PackedVector2Array,loop:bool=true)->Error validates >=2 finite
  points with distinct adjacent centres before changing anything, copies the input
  and configures the path. First configure starts when mounted. Later path changes
  preserve dismissal; hidden hand never resurrects from resize/configuration.
- play()->Error explicitly restarts a configured path. readonly points, state and
  hand_position expose copied path and presentation. State is playing/static/hiding/
  hidden/finished. Normal motion traverses each segment in Motion.SLOW, Ease.IN_OUT,
  pauses Motion.BASE at the end and repeats when loop=true. Nonloop stays at endpoint.
- hide_for_touch()->void suppresses further automatic display and fades Motion.FAST;
  repeated touch is a no-op. cancel()->void immediately hides and kills owned work.
  Component consumes no input and never detects/persists a first word by itself.
- Reduced motion uses a static full-path arrow, no hand movement. A live reduction
  settles playing to static immediately; no idle processing/redraw. Explicit play
  chooses the current motion preference. Exit cancels/disconnects owned work, retained
  entry stays hidden until explicit play. No old tween survives a replacement.
- Gallery page composes actual wheel, inline translated Caption and replay/hide
  controls. Uses seeded wheel order and recomputes the caller-local path after layout.
  Gallery Reduced-motion toggle demonstrates the static arrow. Wheel touches hide the
  hand without blocking an actual swipe. No save/service, boot or Level change.

## UX rules
R-UI-1: this is the explicitly planned component task; screens only compose it.
DESIGN.md#rules-quote-these-into-ui-tasks: R-UI-3 Tokens/theme only; R-UI-4 translated
copy; R-UI-5 generated themes unchanged. R-UI-6 native COMPACT/REGULAR/TABLET ×
PL/PSEUDO × default100/HC130 with playing/hidden/static evidence. Device feel remains
T-0282 and T-0326 does not claim gameplay tutorial integration or device approval.

## Tests
Public catalog behavior: validation/copy, token-stepped segment/end/loop motion,
nonloop endpoint, interrupted replacement, touch fade + hidden resize/configure,
reduced before/live/static with no idle work, retained exit cleanup, theme changes,
native swipe through overlay, gallery registration and 12-case geometry/caption.
Existing tests unchanged. Full pinned make check, scope, fresh review and all15 CI.
