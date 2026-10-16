# Monetization contract and Fake flows (T-0261, T-0263, T-0271)

No boot/view caller activates this service. Inject Clock through initialize, then
configure(save, config, events, consent, ads, ios) with loaded Save/Config and
explicit adapters. Configuration performs no provider operations; pending steps
must settle or expire before reconfiguration.

| API | Result |
|---|---|
| start_session() -> Error | Silent consent info refresh once per configured launch |
| before_next_level(completed_slot: int) -> Error | Serialized campaign Continue, positive completed slot |
| continuation_ready(completed_slot: int) | Exactly one domain completion after due steps/error/cancellation |
| expire_operation() -> void | Cancel pending step; retry unresolved steps next Continue |
| ads_ready() -> bool | True only after consent gates and initialized callback |
| can_offer_interstitial(state: Dictionary) -> bool | Owned readiness/entitlement/history/budget override caller data |
| rewarded_state() -> StringName | unavailable, ready (may attempt explicit load), busy, pending_reward |
| request_rewarded(placement: StringName, reward: Callable) -> Error | Opt-in load/show or identical pending settlement retry |
| purchase(product_id: String) -> Error | Explicit IAP request after configure_iap |
| restore_purchases() -> Error | Request provider non-consumable restore |
| process_unfinished_transactions() -> Error | Retry settlement, then fetch unfinished |
| audio_pause_requested(paused: bool) | Actual opened/ended ad pause boundary |

Legal states: idle -> info -> required form at/after completed UMP slot -> iOS ATT
at/after completed ATT slot -> SDK initialization callback -> idle/continue.
Before the iOS ATT slot, Continue completes without SDK initialization or ad requests.
Android skips ATT. Terminal ATT denial/restriction resolves the tracking prompt;
it does not authorize analytics. UNKNOWN/NOT_DETERMINED and failures leave ads disabled.
Info refresh never opens a form without a due campaign Continue.

ConsentAdapter.analytics_resolved(bool) carries a purpose-specific, legally/provider
verified decision. It alone is relayed to Events.consent_changed. UMP enum outcomes
and ATT authorization do not imply that decision. ConsentAdapter.operation_failed
ends the current legal operation. AdsAdapter initialized, interstitial_loaded and
ad_opened distinguish actual readiness/display from issuing commands. Adapters
must correlate pending operations and suppress obsolete callbacks; the service
rejects callbacks outside the matching step.

expire_operation remains the cancellation seam. T-0263 supplies internal one-shot,
120-second technical watchdogs driving cancellation; they ignore Engine.time_scale
and tree pause. No timeout config key or polling is introduced. Fakes discard old
controlled tokens when commands are superseded; callbacks outside active states
cannot grant, resume or initialize. Expired legal operations stop analytics relay
until a new legal operation starts.

Reward placements are hint, double_reward and shop_coins. reward must be a bound
Economy.grant(source, amounts) for the same Save. Arguments are snapshotted before
showing; arbitrary callables, invalid reasons/amounts and foreign owners are rejected.
Only an opened ad's first reward-earned event may settle the grant. Closing early,
failure, duplicates and timeout never invent reward entitlement. The callback result
is Error; an interrupted write becomes pending_reward, blocking replacement flows
and reconfiguration. Repeat the identical placement/owner/source/amounts explicitly
to retry the pending durable grant without another ad. Reconstructed equivalent
callables are accepted; a completed grant cannot be settled twice.

shop_coins requires source rewarded_coins and the configured economy.reward.rewarded_coins
amount. The existing shop_coins_ads local-day cap is reserved durably after earning
and before granting; failed reservation retries the same candidate once. A later
local day resets the cap; rollback fails closed. There is no process-death exactly-once
reward journal: this task promises in-process retry, not recovery of an unjournaled
ad entitlement after the process dies.

Interstitials are evaluated only on campaign Continue, using actual readiness and
owned entitlement/purchase history. Unloaded/failed ads skip silently and preload
for a later Continue. Timestamp/cooldown and shared automatic prompt counters update
only after opened, before external audio observers run. Missing historical slot
evidence after restart conservatively delays ads rather than inventing a past slot.

Audio.bind_monetization(source) connects the pause signal. set_ad_paused(bool) and
application background are separate pause reasons; neither overwrites persistent
volume/mute settings. No sounds start while either reason applies.

## Explicit IAP settlement (T-0271)

configure_iap(economy, adapter: IapAdapter) -> Error binds the matching loaded Save
and Economy, without provider calls. Frozen consent configuration is unchanged;
without this explicit binding all three IAP commands remain ERR_UNAVAILABLE.
purchase_state() -> StringName and purchase_state_changed(product_id: String,
state: StringName, error: Error) report idle/purchasing/pending/settling/completed/
cancelled/failed/unknown. Commands returning OK mean accepted, not purchase success.
Each verified transaction update is serialized independently; the frozen adapter
has no end-of-fetch/restore signal, so no aggregate completion is fabricated.

Only valid PURCHASED updates for the two canonical P2 products can settle. Pending,
deferred, cancelled and failed cannot grant or finish. Adapters own verification
and non-consumable filtering for restore. Unsolicited verified purchases follow the
same settlement path; provider callbacks may arrive independently of UI commands.

Economy.grant_purchase(store_key: String, product_id: String) -> Error extends the
wallet owner's grant path without changing grant/spend. The configured coin amount
comes from iap.coins_s.amount, never provider metadata. Remove Forced Ads is only
set true. Save.stage_purchase(economy: Dictionary, monetization: Dictionary) -> Error
validates the whole paired document before staging either section. The wallet or
entitlement, permanent processed_transactions entry and purchase-history fields
reach one Save.flush together. Campaign AtomicRequest is unchanged. Processed keys
are never trimmed. No new save field, schema, config key or balance value.

A pending purchase blocks other Economy work/owner replacement and hides its dirty
wallet. Retry reconciles a matching committed pair even if another owner flushed
it after an error, emitting its Economy notification once. A conflicting committed
wallet or missing expected entitlement cannot certify the pair; it remains blocked
without acknowledgement. Retries preserve unrelated section changes. Only committed
Save evidence after Economy reconciliation permits finish. Duplicates finish without
a new grant; crashes before acknowledgement replay through the same key.

One pending purchase command cannot be superseded by fetch/restore or another
purchase. A provider pending product cannot be purchased again; recovery can still
fetch its eventual outcome. A one-shot 120-second technical timer marks unanswered
purchase unknown, keeps its product blocked and permits later callback/recovery.
It ignores scene pause/time scale. Rewarded ads and active purchase presentation
are mutually excluded; already-earned reward retries remain available.

Completed means the local pair is durable and finish was requested. The adapter
has no acknowledgement callback; unfinished replay handles a lost finish. Binding
does not run boot fetch: future activation must explicitly invoke recovery once
per startup. No boot/Nav activation, live provider, endpoint, SDK permission,
store verification implementation, analytics producer or catalog/price approval.
