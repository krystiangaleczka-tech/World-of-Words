---
id: T-0328
title: Observe truthful P2b consent, monetization and onboarding analytics
epic: E21
type: feat
area: services.analytics
risk: high
executor: sol
think: high
ui: low
status: review
depends_on: [T-0251, T-0255, T-0263, T-0271, T-0274, T-0279, T-0286, T-0292]
touch:
  - game/services/events.gd
  - game/services/analytics/analytics_listener.gd
  - game/services/monetization.gd
  - game/services/monetization/ad_presentation.gd
  - game/services/monetization/iap_flow.gd
  - game/platform/iap/store_transaction.gd
  - game/platform/iap/iap_adapter.gd
  - game/platform/iap/iap_fake.gd
  - game/features/level/level.gd
  - game/features/level/stuck_offer.gd
  - game/features/level/paid_tools_ui.gd
  - game/features/level/complete_ui.gd
  - game/features/shop/shop.gd
  - game/tests/integration/test_analytics_p2b.gd*
  - docs/contracts/monetization.md
  - docs/qa/T-0328/**
  - tasks/T-0328-analytics-p2b.md
revision: 3
---

## Goal
Complete ROADMAP T-0328 with truthful existing canonical P2b events through the durable consent-gated Analytics boundary. No double reporting, speculative rewards, SDK activation or changes to gameplay decisions.

## Context
- docs/PRODUCT.md#core-events-seed-of-the-registry and docs/PRODUCT.md#funnels own the event names and payloads.
- docs/ARCHITECTURE.md#analytics-audio-localization keeps Analytics/Events observers only.
- docs/DESIGN.md#pr-screenshot-rules applies to unchanged visual compositions touched by notification hooks.

## Current state / preflight
Fresh main f92ffd5, clean. All listed dependency implementations are merged; task files commonly retain review status after merge.
AnalyticsListener observes settings_changed and feature_unlocked already, but not Events.onboarding_step. Config owns remote_config_applied/experiment_assigned directly. These owners must remain single producers.
Monetization owns consent/ATT and AdPresentation/IapFlow operations, with injected Events. None emits provider telemetry. Adapter errors contain arbitrary text. StoreTransaction currently has key/product/state only; IapAdapter lacks terminal restore evidence. ShopSheet and Level reward controls know actual visibility and availability; LevelStuckOffer already emits stuck_offer_shown exactly once per visit.
All canonical definitions already exist in game/data/analytics; no registry/schema change is required. Fake providers are explicit/manual and native SDKs remain unactivated.

## Specification
- Add typed Events.p2_analytics(name:StringName,params:Dictionary) as side-effect-only copied receipts. Listener accepts only this task's consent/ad/IAP/shop/stuck canonical names; unknown or invalid payloads never become alternative arbitrary analytics ingress. Connect onboarding_step (1..6), preserve settings/unlock/config ownership, disconnect on rebind/exit. Track only through Analytics.track; queue errors/full/denial cannot affect business results.
- Consent result waits for both explicit analytics purpose decision and known UMP state. ads_allowed derives from the accepted UMP permission, never guesses analytics permission from ATT/UMP. Emit consent_changed before reporting a resolved/revoked decision so denial policy applies. Coalesce identical consent snapshots. ATT reports accepted authorized/denied/restricted callback only, once per accepted operation. Bounded enum status strings; never provider text.
- AdPresentation reports shown on first accepted opened callback, reward_earned on first accepted provider-earned callback (not grant success), and failed only on active failure/timeout. Use frozen placement, format and bounded codes no_fill/provider_error/timeout. No duplicate callback event or retry-as-second-reward. Interstitial offer follows approved show decision, before provider dispatch. Rewarded offer comes from an actual visible enabled control, once per UI visit; not from API invocation, unavailable UI or settlement retry.
- ShopSheet reports shop_opened once per actual catalog visit, bounded origin level/unknown; alternatives do not count. Shop coins/hint/x2 enabled reward controls report their actual placements on first visible eligibility. Repeated refreshes do not replay offers; dismiss/new visit may report again. Level's existing injected Events receives stuck offer trigger/slot. No visual, translation, navigation or reward changes.
- Explicitly extend StoreTransaction constructor with backward-compatible optional verified price_micros:int=-1 and price_currency:String="" and restored:bool=false. Fake fixtures may supply these exact optional fields; copy/freeze them through callbacks and queues. Verified restore updates carry restored=true so an unrelated purchase during an asynchronous restore remains a purchase. Never parse localized price strings or assume zero/fictional currency. A fresh durable purchase emits completed only with nonnegative safe integer price and three uppercase currency letters from its verified envelope. Missing/invalid metadata skips this event without affecting grant/finish. Already-processed duplicate updates do not replay it. Started follows accepted purchase; failure/cancel/timeout uses bounded codes and canonical product only. No receipt/token or localized price reaches analytics.
- Explicitly extend IapAdapter with restore_completed(transactions:Array[StoreTransaction]), an authoritative terminal batch for the current requested restore; native adapters must suppress stale callbacks. Fake emits a copied nonconsumable batch only after a successful live restore replay, including an empty batch; errors/cancellation/superseded operations do not emit success. This is telemetry evidence, not a new grant protocol.
- IapFlow observes restore independently of gameplay busy/pending decisions. Count unique nonconsumable keys only once after terminal evidence AND durable processed-key proof. Retain failed-write evidence transiently until existing explicit settlement retry succeeds; do not announce pending/failed/unfinished fetch as restore success. Restore replay is not a new purchase completion. No new persistence/schema, economic rules, consent policy, SDK, endpoint, secrets, dependencies, autoloads or initialization.

## View observation interfaces
Explicitly add Monetization.observe_shop_opened(origin:StringName=&"unknown")->void and observe_rewarded_offer(placement:StringName)->void as side effects only, with no provider command or permission decision. ShopSheet.configure gains an optional third origin:StringName=&"unknown" parameter, retaining all two-argument callers. Level's composition bridge remains internal; no existing signal signature changes.

## Tests
New isolated GUT integration tests with actual runtime Analytics/FIFO, Save/Economy/Monetization and fake adapters cover consent/ATT ordering and deduplication, unknown/denied/full queue, valid whitelist and teardown/rebind, committed onboarding (failed write/retry/duplicate), unchanged settings/unlock/config producer ownership; rewarded opened/earned/early close/failure/timeout and duplicates/retry, interstitial proof; fresh/duplicate/failed/pending/cancelled IAP and missing price, verified-price freeze, no token/text leakage; authoritative restore including empty, duplicate, consumable exclusion, failed durable write then explicit retry; actual visible Shop/alternative/offer refresh and stuck offer bridge. Existing full regressions pass unchanged. Native CI gallery artifact verifies unchanged components; no device certification claim.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1: A screen task may not create a component. R-UI-2: New component = separate task including its gallery entry. R-UI-3: No raw visual values; all existing styles/tokens remain. R-UI-4: Player strings use translation keys; no copy changes. R-UI-5: Never hand-edit generated themes. R-UI-6: Attach gallery evidence as required; this task adds notification hooks only.

## Acceptance
make check, independent fresh pack review and all 16 exact-head CI checks including both Android builds and actual gallery artifact pass. QA records the complete producer matrix and missing-native-metadata behavior. One task/branch/PR, no ROADMAP edits.

## Rollback
Revert the squash. Optional metadata/terminal signal are backward-compatible and no persisted data changes.
