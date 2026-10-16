---
id: T-0285
title: Compose an explicit catalog Settings screen
epic: E21
type: feat
area: features.settings
risk: medium
executor: sol
think: med
ui: high
status: review
depends_on: [T-0284, T-0218]
touch:
  - game/features/settings/*.gd*
  - game/features/settings/*.tscn
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_screen.gd*
  - docs/qa/T-0285/**
  - tasks/T-0285-settings-screen.md
  - tasks/T-0284-settings-contract.md
revision: 1
---

## Goal
Compose DESIGN.md#settings without activating boot/Nav, persistence or external actions.

## Current state
Save's seven settings accessors and committed_view exist. TopBar, ListRow,
CatalogSlider, Toggle, Sheet, TextButton, StatePanel, Toast exist. No Settings scene.
Contract: docs/contracts/settings.md. T-0284 is merged before implementation.

## Specification
SettingsScreen.configure(save:Node)->Error before mount. Show all sound/display/
language/purchases/privacy/about rows in a vertical ScrollContainer. Use actual
committed values, version/install ID and owned entitlement. Privacy Options hidden
unless set_privacy_options_available(bool) explicitly enables it. Only signals:
back_requested, setting_requested(key,value), action_requested(action).
No writes, sound, SDK, navigation, URL/mail or fake restore outcome. Disable owned
remove-ads row. Theme/text/locale changes reflow; no duplicate intents on reentry.
Screen owns caller-owned trailing controls. Text-size/language rows emit intent;
their working options and persistence arrive in T-0286/87. Source keys settings.*.
Reconcile merged T-0284 metadata to done.

## UX rules
DESIGN.md#rules-quote-these-into-ui-tasks: R-UI-1/2 catalog only; R-UI-3 tokens;
R-UI-4 translated keys; R-UI-5 generated theme untouched; R-UI-6 native COMPACT/
REGULAR/TABLET x PL/PSEUDO x default/HC130 evidence and mockup comparison.
Reference DESIGN.md#settings. Physical device/taste gate remains open, as T-0276.

## Tests
Real Save: copied committed values; no mutation on native control/action intent;
owned/consent visibility; scroll reaches about; native keyboard; reentry once;
12-case geometry/scroll/HC130/PSEUDO matrix. Full checks, fresh review, CI green.
