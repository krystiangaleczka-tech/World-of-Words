---
id: T-0261
title: Define the Monetization consent, ads, entitlement and IAP contract
epic: E18
type: contract
area: services.monetization
risk: high
executor: sol
think: xhigh
ui: none
status: review
depends_on: [T-0260, T-0229, T-0233, T-0250]
touch:
  - game/services/monetization.gd
  - game/platform/ads/ads_adapter.gd
  - game/platform/consent/consent_adapter.gd
  - game/tests/integration/test_monetization_contract.gd*
  - tasks/T-0261-monetization-contract.md
  - tasks/T-0260-ad-policy.md
revision: 1
---

## Goal
Define the typed Monetization service boundary that T-0263 (consent and ads) and T-0271 (IAP)
implement: one next-level gate, correlated rewarded offers, the Remove Forced Ads entitlement and
the purchase entry points. This contract adds fail-closed stubs only; nothing is shown, granted,
persisted or emitted. Owner asked to create and execute the next roadmap task.

## Context
- ARCHITECTURE.md#monetization-flows — "The ads SDK is initialized only after consent resolves; on
  iOS, after ATT too (FR-ADS-06)." "An unresolved step retries at the next Level complete."
- DESIGN.md#flow-level-complete step 4 — "Continue -> UMP or ATT step if due -> interstitial if
  `ad_policy` allows -> next level."
- GAME_DESIGN.md#p2-economy-scope-and-ownership — "Rewarded offers correlate the active
  offer/placement and grant once only on the reward-earned callback. Late/duplicate callbacks cannot
  manufacture another grant."
- GAME_DESIGN.md#p2-consent-and-collection-policy — "UMP/ATT outcomes alone do not prove analytics
  or crash permission."
- Roadmap T-0261; FR-ADS-04..06, FR-ADS-08, FR-CONSENT-01, FR-IAP-03, FR-IAP-04.

## Current state
- `game/services/monetization.gd` extends ServiceStub with no domain methods; Nav lists it as an
  autoload. Save v4 `monetization` holds `remove_forced_ads`, `processed_transactions`,
  `last_interstitial` (legacy), `levels_since_interstitial`, `levels_since_purchase` (legacy),
  `shop_coins_ads {date,count}`, `last_interstitial_time`, `last_purchase_slot`, `consent_state`.
- `AdPolicy` (T-0260, merged) exposes should_show_interstitial, can_show_prompt, next_prompt_count.
- `Events.consent_changed(analytics_allowed: bool)` exists (T-0250); Analytics queues until it fires.
- `AdsAdapter` has rewarded_loaded, reward_earned, ad_closed, ad_failed(reason) and no interstitial
  availability signal. `ConsentAdapter` has consent_resolved(State), att_resolved(AttStatus) and no
  analytics-purpose result. IapAdapter/StoreTransaction carry store_key, product_id and state.
- Economy.grant/spend are durable; Progress exposes highest_completed_slot. Audio has no pause API.
- T-0260 is merged; its status is reconciled to done here.

## Specification
### Behavior (this task)
1. Add the interface below. Every method is inert even after configure with valid dependencies:
   is_ready false, start_session/show_privacy_options/before_next_level/purchase/restore_purchases
   ERR_UNCONFIGURED, show_rewarded 0, rewarded_available/privacy_options_available/
   has_remove_forced_ads false, consent_state the independent unknown default. No Save, Config,
   Economy, Progress or adapter calls, no signals, no boot wiring, no callers.
2. Add `AdsAdapter.interstitial_loaded` and `ConsentAdapter.analytics_purpose_resolved(allowed)`.
   Fakes inherit them and still never emit them by themselves.

### Behavior (binding for T-0263 / T-0271)
3. **Session.** start_session(): refresh UMP info silently (FR-CONSENT-01), never shows a form,
   records session start from the injected Clock, and (T-0271) fetches unfinished transactions.
   Prompt budget (`AdPolicy`) is per session and counts only displayed automatic prompts.
4. **Next-level gate.** before_next_level(slot) is the only entry point after Continue on a completed
   campaign level. Non-OK return: no signal follows and the caller loads the next level at once.
   OK: exactly one next_level_cleared(slot, steps) follows; steps lists what ran, in order, from
   `ump`, `att`, `interstitial`. Order: UMP step if slot >= `consent.ump_after_slot` and unresolved;
   then on iOS ATT if slot >= `consent.att_after_slot` and unresolved; then the interstitial
   decision. A second call while one is open returns ERR_BUSY. Any error, no fill or failed form
   clears the gate without blocking; an unresolved step retries at the next call. Daily puzzles and
   app open never call it (FR-ADS-03).
5. **Consent.** The ads SDK is initialized once, only after UMP resolves, with the resolved state;
   on iOS no ad is loaded or requested before ATT resolves (FR-ADS-06). ATT denial still allows the
   non-personalized path. Events.consent_changed is emitted only from
   analytics_purpose_resolved, never inferred from UMP or ATT; without it the analytics queue stays
   local. Privacy options are available only when UMP reports them required (FR-CONSENT-03).
6. **Interstitial.** State for AdPolicy.should_show_interstitial: context `campaign_continue`,
   sdk_ready, ad_loaded (latest interstitial_loaded since the last show), remove_forced_ads,
   completed_slot = slot, last_interstitial_seconds = last_interstitial_time or -1,
   last_interstitial_slot = slot - levels_since_interstitial when a time exists else -1,
   session_start_seconds, last_purchase_slot or -1, prompts_used. levels_since_interstitial is
   incremented once per accepted slot (a repeated or lower slot in a session does not count) before
   the decision. After the ad closes: time = now, counter = 0, prompt counted, then persist through
   the monetization section. Ineligible or not loaded: skip silently.
7. **Rewarded.** Placements `hint`, `double`, `shop_coins`. show_rewarded returns a new positive
   offer id or 0 when rejected (unknown placement, disabled config key, unavailable, busy, shop cap
   reached). One active offer at a time. Exactly one rewarded_finished(placement, offer_id, outcome)
   per accepted offer with outcome `earned`, `closed_early`, `unavailable` or `failed`. `earned`
   comes only from reward_earned during the active offer; late or duplicate callbacks are ignored
   (FR-ADS-04). `hint` and `double` grants belong to their placement owners (T-0278, T-0281) on
   `earned`; `shop_coins` is granted by Monetization via Economy.grant with
   `economy.reward.rewarded_coins` and counted in shop_coins_ads per local day key.
8. **Audio and background.** ad_presentation_changed(true) before any full-screen ad or consent
   form, false after it resolves, always paired (FR-ADS-08). Backgrounding never resolves a step by
   itself; the adapter callback on resume does.
9. **Entitlement and IAP.** has_remove_forced_ads reads the committed section; once true it is never
   cleared locally (FR-IAP-11) and it suppresses interstitials only, never rewarded (FR-ADS-07).
   purchase(product_id) accepts only PRODUCTS. A transaction whose store_key is already processed
   only finishes. Otherwise: grant or set entitlement -> append store_key -> durable Save.flush ->
   finish (FR-IAP-03/04); last_purchase_slot = Progress.highest_completed_slot at grant.
   purchase_updated(product_id, state) follows durable success; restore covers non-consumables only.

### Interface
```gdscript
## @api
const PLACEMENTS: Array[StringName] = [&"hint", &"double", &"shop_coins"]
const PRODUCTS: Array[StringName] = [&"nc.remove_forced_ads.v1", &"c.coins_s.v1"]
signal next_level_cleared(slot: int, steps: PackedStringArray)
signal rewarded_finished(placement: StringName, offer_id: int, outcome: StringName)
signal ad_presentation_changed(active: bool)
signal purchase_updated(product_id: StringName, state: StringName)
func configure(save, config, events, economy, progress, platform, ios: bool) -> void
func is_ready() -> bool
func start_session() -> Error
func consent_state() -> Dictionary  # {ump: StringName, att: StringName, ads_initialized: bool}
func privacy_options_available() -> bool
func show_privacy_options() -> Error
func before_next_level(slot: int) -> Error
func rewarded_available(placement: StringName) -> bool
func show_rewarded(placement: StringName) -> int
func has_remove_forced_ads() -> bool
func purchase(product_id: StringName) -> Error
func restore_purchases() -> Error
# AdsAdapter: signal interstitial_loaded
# ConsentAdapter: signal analytics_purpose_resolved(allowed: bool)
```

### Edge cases
| Case | Expected |
|---|---|
| Stub configured with real Fakes | still inert, no adapter calls recorded |
| before_next_level returns non-OK | no next_level_cleared; caller proceeds |
| reward_earned with no active offer (T-0263) | ignored, no grant |
| Already processed store_key (T-0271) | finish only, no grant |

## Out of scope
Implementation (T-0263, T-0271), Fake debug outcomes (T-0262, T-0270), Audio pause wiring, Save
schema, config keys, analytics events, boot wiring, UI and SDK adapters.

## Tests
`game/tests/integration/test_monetization_contract.gd`:
- Typed interface fails closed before initialize/configure and after configure with Fakes.
- Returned consent_state is independent; no Save calls, adapter calls or signals after any stub call.
- Signal names and argument counts match the interface; new adapter signals exist on Fakes.
- PLACEMENTS and PRODUCTS match the canonical IDs.

## Acceptance
Only touch files change; new tests and make check pass.

## Rollback
Revert unused stubs and two unemitted adapter signals; no persisted data changes.

## Escalation log
