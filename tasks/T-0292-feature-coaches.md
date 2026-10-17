---
id: T-0292
title: Present durable nonblocking feature coaches on Level and Home
epic: E21
type: feat
area: level.flow
risk: medium
executor: sol
think: high
ui: high
status: review
depends_on: [T-0291]
touch:
  - game/features/onboarding/feature_coaches.gd*
  - game/features/level/level.gd
  - game/features/level/stuck_offer.gd
  - game/features/home/home.gd
  - game/locale/onboarding.csv*
  - game/tests/integration/test_feature_coaches.gd*
  - docs/qa/T-0292/**
  - tasks/T-0292-feature-coaches.md
revision: 2
---

## Goal
Explain shuffle, bonus, hint, reveal and Journey once using existing highlighted
controls and inline captions. A coach never consumes the player's tap or forces an action.

## Context
- ROADMAP T-0292, FR-ONB-03; DESIGN.md#feature-unlock-gating: "Any tap anywhere dismisses it" and "No overlay, no scrim, no arrow, no new component".
- GAME_DESIGN.md#onboarding: first eligible bonus at bonus unlock, Journey NavTab on first eligible Home; queue behind consent/other coach/completion feedback.
- docs/contracts/onboarding.md#coachmark-presentation-protocol-t-0292: validate, persist before display, exact failed-action retry; at-most-once authorization.
- docs/qa/T-0201-onboarding-plan.md approved copy; docs/design/T-0205 accepted coach mockups (compact gutters and wheel floor 450).

## Current state
- Save.configure_onboarding(events), onboarding_snapshot(), mark_coach_seen(feature) persist the closed shuffle/bonus/hint/journey/reveal IDs and publish existing onboarding_step. Different pending actions reject each other.
- ActionButton.highlighted is inherited by IconButton, HintButton, BonusMeter and NavTab. No CoachMark widget is needed. LocaleCatalog discovers imported CSVs.
- LevelScreen.configure_p2 opts in before mount; p2_hud owns exact shuffle/meter/hint/reveal targets. controller state_changed/result_ready and manual refresh are available. paid_tools_ui exposes modal_open/reward_busy; completion, wheel locks and stuck_offer caption expose competing presentation.
- Home.configure injects Save/Content/Config/Nav before mount. Its Journey NavTab is created in _ready as bottom chrome; refresh reads committed campaign progress.
- LevelStuckOffer._hide currently clears HintButton.highlighted even when no offer was visible; coordinate ownership explicitly in this task.
- No coach presenter, locale resource or opt-in APIs exist. Boot/Nav and consent SDK activation stay unchanged.

## Specification
1. Add caller-owned Node FeatureCoaches, not a UI component. configure(save,events,eligible:Callable,blocked:Callable)->Error binds loaded real Save/Events before mount. show(feature:StringName,target:Control,caption:Label)->Error, dismiss()->void, active_feature()->StringName, refresh()->void, retry()->Error, prepare_navigation()->Error expose the protocol. Only closed feature IDs and ActionButton targets with passive hidden captions are accepted; host eligibility certifies exact target identity and real committed unlock state.
2. Validate before marking seen. Suppress already-seen independently of max step; tutorial step>=1 required. Persist Save.mark_coach_seen(feature) successfully before highlighting/showing the caption. Freeze request and guard reentry through synchronous Save/event callbacks; revalidate target eligibility/blocking after commit and skip paint if unsafe. No fabricated events, wallet/progress writes or budget changes.
3. One active coach; queue eligible requests FIFO behind another coach or caller consent/host modal/completion blockers. Queueing consumes no Save flag. Refresh explicitly after blockers resolve; no polling/automatic retry of failed I/O. Exact failed request remains pending, shows nothing, and retry targets its named feature, never another owner's pending action. An unrelated successful flush may consume authorization; do not replay it on reopening. Navigation resolves pending metadata without briefly painting a coach. Exit cancels owned visuals/timer and queued requests; retained entry cannot replay seen coaches.
4. Any native left mouse press or non-canceled screen touch anywhere dismisses without marking input handled. Timeout is Tokens.Motion.TOAST_HOLD*2; use a one-shot Timer. Do not advance another queued coach during that same input dispatch. Dismiss clears only the owned caption/highlight/timer, never a pre-existing foreign highlighted state. Coordinate StuckOffer so it cannot overwrite an active coach or clear a highlight it did not show.
5. Explicit LevelScreen.configure_coaches(blocked:Callable)->Error before mount requires P2 and matching campaign Save; default P1/P2 and boot unchanged. Caller supplies real consent/foreign-modal guard and calls refresh_coaches() at its resolution boundary. Host also blocks paused tree, paid modal/reward/transaction, completion, wheel drag/lock, and an existing stuck offer. Refresh at controller state/result boundaries; targets must be visible/unlocked at canonical config thresholds. Bonus requires a currently eligible committed bonus word, including restore. Coins and x2 never coached. Tutorial is a prerequisite, not inferred from progression.
6. Explicit Home.configure_coaches(events:Node,blocked:Callable)->Error before mount; only eligible visible implemented Journey NavTab at current committed journey threshold. The caller's consent/modal guard is mandatory. Same presenter/protocol. Home prepares navigation through the helper.
7. Caller-provided inline Caption uses onboarding.coach.<feature> and approved PL/EN copy. Reserve stable gutters for Level coaches with existing Tokens.Layout.WHEEL_MIN; no geometry change on dismissal/native press. Caption sits beside its target, outside wheel tile hit circles. Bonus caption beside meter, Journey caption beside NavTab in stable bottom row. Locale/theme/130%/PSEUDO layout updates; reduced motion retains static highlight and timeout.

## UX rules
- R-UI-1 "A screen task may not create a component"; R-UI-2 "New component = separate task". Reuse highlighted catalog targets and Caption only.
- R-UI-3 "No raw numbers in scenes or feature scripts"; use Tokens/theme. R-UI-4 "Strings shown to players use translation keys".
- R-UI-5 "Never edit game/ui/theme/generated/". R-UI-6 "Every UI PR with UI: med|high attaches screenshots".
- Screenshots per DESIGN.md#pr-screenshot-rules; native matrix three layouts × PL/PSEUDO × default/HC130, all five coaches. Physical device/FUN/playtest gates remain open.

## Tests
File game/tests/integration/test_feature_coaches.gd:
- Invalid/unconfigured/off-campaign/hidden/foreign-highlight targets and unrelated caption reject without Save write or state damage; canonical unlock boundaries and bonus-first discovery; tutorial prerequisite.
- Persist-before-paint observed by real Events; duplicate seen independent from higher step, restart/retained entry no replay, blocked queues and FIFO single active, explicit resolution refresh.
- Failed I/O and exact explicit retry; other pending feature isolated; unrelated flush/reentry; reentrant Save callbacks cannot swap or display another request; navigation retries without paint.
- Native touch and mouse anywhere dismiss while same press/drag/release reaches actual wheel/button, no forced action. Token timeout, reduced motion, exit cleanup, target removal and foreign highlight preservation.
- Actual opt-in Level and Home integration, P1/P2 defaults unchanged, modal/completion/consent blockers, StuckOffer ownership, committed bonus eligibility, layout matrix and captions clear of tile hit circles.

## Acceptance
Pinned make check, scope/task lint, fresh independent review and all CI including Android pass. Native evidence does not certify physical-device gates.
