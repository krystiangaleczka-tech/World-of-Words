---
id: T-0278
title: Integrate durable paid Hint and Reveal with fallback offers
epic: E20
type: feat
area: level.hud
risk: high
executor: sol
think: high
ui: high
status: review
depends_on: [T-0276, T-0277, T-0263, T-0274, T-0336, T-0337]
touch:
  - game/features/level/level.gd
  - game/features/level/level_controller.gd
  - game/features/level/p2_hud.gd
  - game/features/level/paid_tools_ui.gd*
  - game/features/shop/shop.gd
  - game/services/monetization.gd
  - game/locale/level.csv*
  - game/tests/integration/test_paid_tool_flow.gd*
  - docs/contracts/paid-tools.md
  - docs/qa/T-0278/**
  - tasks/T-0278-paid-tools.md
revision: 2
---

## Goal
Use owned tools or coins only through the durable paid-tool protocol, and offer an
explicit rewarded Hint or Shop alternative when the player cannot pay.

## Current state
T-0336 adds paid requests and exact owner/content/config certification to the existing
AtomicProgressPort. T-0277 supplies pure Reveal selection. LevelScreen.configure_p2
currently displays HUD intents without paid mutation; controller.hint remains P1 free.
ShopSheet owns the actual provider-backed catalog, Sheet supports caller-owned content
replacement, Monetization.request_rewarded accepts bound Economy.grant callbacks.

## Specification
- LevelScreen.configure_paid_tools(progress, port, monetization=null, ios=false)
  is an explicit before-mount opt-in after configure_p2. Require exact certified
  Save/Progress/Economy/Content/Config/port and ready P2 Progress. Boot/Nav unchanged.
  A supplied Monetization must match the same Save/Economy/config; a mismatched or
  unavailable provider is never used. Default presentation-only P2 remains inert. If owners become stale before mounting,
  paid activation fails closed with no controller board or free-hint fallback.
- LevelController.configure_paid_tools(save, port) and use_paid_tool(kind) use
  detached plans and port commands. Retry the exact retained request; never call
  free hint, ordinary spend or complete_level after a paid action. Paid mode is
  latched for that controller instance; configure cannot downgrade it to free. Adopt the board
  only after Save validates the exact matching receipt. Partial/final commits use
  T-0336; preserve existing P1 behavior when not opted in.
- Controller exposes paid_pending/paid_locked/paid_feedback_active and release_paid_feedback; a synchronous
  reentrant action, second click, gesture or reconfigure cannot mutate during an
  unresolved operation or its reveal feedback. Unresolved errors retain the board
  and show an explicit retry button; block navigation/background checkpointing.
- On success emit local paid_tool_committed(kind, new_cells), refresh the board and
  wallet, animate catalog BoardView feedback and release input using token duration
  (at least a frame in reduced motion). Kill timers/disconnect on exit; reentry
  restores feedback/retry ownership. Persist-before-leave returns busy while pending.
- Unaffordable opens Hint options Sheet: ad-badged SecondaryButton for configured
  rewarded Hint items, Get coins and Not now. Disable unavailable ad with inline
  explanation. Reward only through the existing bound Economy.grant; do not auto
  spend/reveal, especially for an original Reveal intent. Show grant success, early
  close/no-fill, pending write retry and busy/back behavior through actual service state.
- Add ShopSheet.open_alternative(content, title) and open_shop_content() to replace
  content within the SAME Sheet. Existing Shop API behavior remains unchanged.
  Get coins uses the actual catalog if configured, otherwise an explanatory offline
  StatePanel in the same Sheet. Never nest sheets or invent prices/readiness.
- Use existing catalog components and Tokens only. New PL/EN strings in level.csv.
  Payment analytics integration remains T-0275; do not fabricate P1 paid events.

## Interface refinement
LevelP2Hud keeps its presentation contract. Refresh tool amounts only when count or
price changes, so redundant wallet/HUD refreshes preserve the stock count animation. LevelScreen stores the supplied Economy
and Config identities from configure_p2 for certifies_tools. Monetization's current
shop_snapshot exposes no identity certifier; only use a provider when its configured
bindings can be certified via an explicit read-only
Monetization.matches_tool_owners(save, economy, config) -> bool scoped below before use.

## UX
DESIGN.md#level-p2-final, #flow-stuck-player, #flow-rewarded, #hintbutton, #sheet.
R-UI-1: only components from the catalog. R-UI-3: all visual values from tokens.
Every tappable >= Touch.MIN_TARGET (DESIGN review checklist). One Sheet; every unavailable state has
non-colour explanatory copy. PL/PSEUDO at 130%, default/HC, COMPACT/REGULAR/TABLET;
reduced motion and all supported gesture states. Screenshots per #pr-screenshot-rules.

## Tests
New integration suite: real owners and actual screen/controller for item/coin Hint
and Reveal, final completion, exact failed-write retry, rapid/reentrant action guards,
free-hint bypass prevention, failed/replaced configuration, checkpoint/navigation,
exit/reentry, affordability and ad/Shop alternatives, actual Fake reward/close/failure
outcomes and grant retry. UI geometry/accessibility and twelve-case native matrix.
Existing tests unchanged. Reproduction/captures and real-device limits in docs/qa/T-0278.

## Acceptance
Full make check, scope/task checks, fresh independent review and all CI pass.
No new SDK, balance, save format, autoload, dependency or runtime Boot activation.

## Rollback
Disable paid activation; retain T-0336 reader and committed operation receipts.

## Scope refinement
The UI helper composes existing catalog controls and the existing Shop Sheet; it is
not a new reusable component. The controller/screen lifecycle plus two small Shop
content APIs and the provider identity check form one explicitly opted-in flow.
Normal word submissions retain the existing BoardView nodes; only paid board adoption
rebinds the view. The caller must respect prepare_navigation: a pending screen owns
its exact retry until it is retained/reentered or the process restarts. Forced
screen destruction while ignoring a busy navigation result is unsupported.
