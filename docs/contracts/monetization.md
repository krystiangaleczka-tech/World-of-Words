# Monetization contract (T-0261)

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
| can_offer_interstitial(state: Dictionary) -> bool | Owned readiness/entitlement override caller data; false before T-0263 |
| rewarded_state() -> StringName | unavailable until T-0263 |
| request_rewarded(placement: StringName, reward: Callable) -> Error | ERR_UNAVAILABLE; no callback or grant |
| purchase(product_id: String) -> Error | ERR_UNAVAILABLE until T-0271 |
| restore_purchases() -> Error | ERR_UNAVAILABLE until T-0271 |
| process_unfinished_transactions() -> Error | ERR_UNAVAILABLE until T-0271 |
| audio_pause_requested(paused: bool) | Future presentation boundary; inactive here |

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

expire_operation is the explicit watchdog seam, not an invented timeout config key
or a timer. T-0263 must provide finite cancellation before activation. It also owns
reward-earned-only Economy grants, exactly-once settlement, Remove Forced Ads,
policy/prompt counters, actual audio pause/resume and unavailable presentation.
T-0271 owns transaction idempotency and durable grant/flush/finish. No live provider,
network endpoint, save schema, economy or consent policy is changed here.
