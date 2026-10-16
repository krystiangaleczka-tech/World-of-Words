# Monetization contract and Fake flows (T-0261, T-0263)

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
| purchase(product_id: String) -> Error | ERR_UNAVAILABLE until T-0271 |
| restore_purchases() -> Error | ERR_UNAVAILABLE until T-0271 |
| process_unfinished_transactions() -> Error | ERR_UNAVAILABLE until T-0271 |
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

T-0271 still owns transaction idempotency and durable grant/flush/finish. No boot/Nav
activation, live provider, endpoint, SDK permission, save schema or balance change.
