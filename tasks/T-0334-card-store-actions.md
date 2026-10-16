---
id: T-0334
title: Extend catalog Card actions for store-supplied values and Secondary footers
epic: E19
type: feat
area: ui.components
risk: medium
executor: sol
think: high
ui: med
status: review
depends_on: [T-0217]
touch:
  - game/ui/components/ActionButton.gd
  - game/ui/components/Card.gd
  - game/ui/gallery/content.gd
  - game/tests/integration/test_card_store_actions.gd*
  - docs/qa/T-0334/**
  - tasks/T-0334-card-store-actions.md
  - tasks/T-0274-shop-sheet.md
  - tasks/epics/E19-iap-and-shop.md
revision: 1
---

## Goal
Supply the missing catalog footer states before the Shop screen, per R-UI-1/2.
This is the second of the three owner-authorized serial tasks after T-0271.

## Context
DESIGN.md#shop-sheet requires one Primary, Secondary coin/ad actions and localized
store prices. Existing Card only creates PrimaryButton and rejects interactive body.
P2 rolling-wave split: reserve ID T-0334 for component prerequisite of T-0274.
Mockup: docs/design/T-0205/evidence/shop_COMPACT_PL_default.png.

## Current state
Card.action_key creates a Primary footer; Card.configure_body is passive only.
ActionButton.text_key translates caption; SecondaryButton supports badge empty/ad.
Gallery content and generated themes support all three size classes/HC130/PSEUDO.
No value caption or Card footer variant API exists.

## Specification
ActionButton.value_text: String defaults empty. Non-empty caller-supplied display
value (e.g. localized provider price) overrides visible text_key caption only, never
gets translated/reformatted. text_key remains action/accessibility identity.
Accessibility description uses value_text first, otherwise sublabel_key; sublabel
still translates independently. Clearing value restores translated caption.

Card.configure_action(variant: StringName, key: String, value: String = "",
badge: StringName = &"") -> Error accepts primary/secondary/none, badge empty/ad
only for secondary. Non-none requires key; none requires empty key/value/badge.
Validate atomically before changing any state. Expose readonly action_variant and
action_button()->ActionButton for caller geometry/focus. Legacy action_key remains
Primary by default. Configure before/after mounting and after exit/reentry.
Replace footer only when class changes; old signals/motion cannot emit new intent.
Preserve focus when moving between available variants; none releases hidden footer
focus (card if tappable, otherwise no stale focused footer). Locked/disabled/loading
propagate exactly; busy uses footer spinner and restores correct disabled value.
No new component, styles/tokens, provider service or purchase behavior.

## UX rules
R-UI-1/2 separate catalog task; R-UI-3 token/theme only; R-UI-4 player copy uses keys,
opaque provider values are caller data; R-UI-5 no generated theme edits; R-UI-6 attach
native COMPACT/REGULAR/TABLET x PL/PSEUDO x default/HC130 screenshots.
Physical device/taste/FUN certification remains open; gallery evidence is desktop.

## Tests
New integration suite tests legacy default, variants/badges/atomic invalid input,
opaque value/locale/accessibility, native activation, disabled/loading/locked,
reentrant replacement, focus/none, exit/reentry connections and 12-case layout matrix.
Gallery includes primary/secondary/ad value variants. Required screenshot evidence.

## Acceptance
make check, scope, fresh exact-commit review and CI pass. Existing tests unchanged.
