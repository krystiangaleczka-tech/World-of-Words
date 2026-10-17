---
id: T-0281
title: Compose P2 completion rewards and service-owned Continue
epic: E20
type: feat
area: level.flow
risk: high
executor: sol
think: med
ui: high
status: review
depends_on: [T-0280, T-0242, T-0263, T-0220]
touch:
  - game/features/level/level.gd
  - game/features/level/complete_ui.gd*
  - game/services/nav.gd
  - game/locale/level.csv*
  - game/tests/integration/test_level_complete_flow.gd*
  - docs/qa/T-0281/**
  - tasks/T-0281-level-complete.md
revision: 1
---

## Goal
Present committed P2 completion rewards, postcard progress and optional rewarded
base-reward multiplication; Continue waits for Monetization before Nav routes.

## Context
DESIGN.md#level-complete and #flow-level-complete: "Continue → UMP form (if due)
→ ATT (if due) → interstitial (if policy allows) → next Level."
GAME_DESIGN.md#economy-intents: x2 applies to the base level reward, never chest rewards.
FR-ECON-05, FR-META-01. The existing screen spec supplies the UI-high reference;
physical device review remains a release gate.

## Current state
LevelScreen.configure_p2/configure_paid_tools/configure_bonus_meter explicitly
opt into certified real Progress/Economy owners before mounting. Completion currently
has only title and Continue. LevelBonusUI owns the committed chest presentation.
Save.committed_view exposes eleven-field issued completion receipts, including paid
final completions, delta.stars and level_complete grant notifications.
Monetization.before_next_level emits continuation_ready synchronously or later;
request_rewarded accepts an exact bound Economy.grant and preserves earned failed
writes as pending_reward for retry without another ad. Nav.continue_campaign currently
routes directly to postcard/next level; default P1 and P2 behavior must remain intact.

## Specification
- Add explicit LevelScreen.configure_completion(monetization: Node = null) -> Error,
  before mount, after certified bonus setup. Reject foreign service owners; do not
  activate Boot or SDKs. LevelCompleteUI composes catalog controls into existing
  completion layer and observes its visibility, with exit/reentry cleanup.
- TITLE completion heading, DISPLAY level number, noninteractive star/coin
  CurrencyPills; count actual receipt stars and base reward once when visible.
  Receipt lookup supports ordinary and paid final completion; no live balance
  arithmetic to infer base reward. Existing LevelBonusUI alone presents chest burst.
- Show committed location credits via LocationPostcard thumb when art exists,
  CatalogProgressBar and translated piece counts. Missing art uses translated Caption,
  preserving progress. All spacing/type from Tokens, vertically centered column.
- Secondary rewarded button with ad badge, canonical double_reward_slot/enable flag
  and multiplier. Freeze extra coins from actual base reward at completion. Hide
  after earned durable grant; update coin pill to multiplied base. Keep chest separate.
  A terminal disabled Continue must not prevent claiming x2.
  No grant on no-fill/early close; show unavailable Caption. Earned failed write has
  explicit retry using same bound request, blocks Continue and does not show another ad.
  Preserve once-only UI state on retained reentry; screen recreation cannot remount
  a completed slot through certified paid owner configuration. No save format changes.
- Nav.configure_campaign_continue(service: Node, economy: Node) -> Error explicitly
  binds the same ready service owners for P2. Opted-in continue_campaign validates
  durable completion, then serializes before_next_level with routing/back barriers;
  continuation_ready routes postcard/next through existing Nav policy, not scene logic.
  Handle synchronous callbacks, duplicates, invalid intents, provider busy, watchdog,
  owner reconfiguration, host exit and asynchronous route failure. Emit
  campaign_continue_failed(error: Error) so the screen can re-enable Continue.
- Keep Continue disabled while rewarded work is busy/pending, and protect native
  emitted presses as well as visual state. No polling/provider retries from frames.

## UX rules
DESIGN.md#rules-quote-these-into-ui-tasks: R-UI-1 "A screen task may not create a
component"; R-UI-3 "Use Tokens.*, theme type variations or theme constants";
R-UI-4 translated strings; R-UI-5 generated themes unchanged. Existing catalog only.
Native screenshots per DESIGN.md#pr-screenshot-rules: COMPACT/REGULAR/TABLET ×
PL/PSEUDO × default100/HC130, with geometry assertions; device feel not simulated.

## Tests
New real-owner integration suite: ordinary/paid final receipt values and chest
exclusion; committed postcard progress/missing art; unlock and unavailable states;
reward success/duplicate presses, no-fill/early close, failed write retry; retained
lifecycle and normal/reduced count-up; rejected foreign/late opt-ins; Continue sync
and async provider completion, duplicate/stale signals, busy/back barrier, invalid
intent, route failure retry and host teardown. Existing tests unchanged.

## Acceptance
Pinned full make check, scope, fresh independent Sol review and all15 CI including
both Android builds pass before exact-head squash merge. No Boot activation, real
provider operations, balance/schema or analytics changes.

## Rollback
Remove explicit completion and Nav opt-ins; no persistent schema change.
