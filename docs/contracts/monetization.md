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
Each verified transaction update is serialized independently. Legacy adapters may
omit terminal restore evidence; no aggregate completion is inferred from command
acceptance, individual updates or an unfinished-transaction fetch. T-0328 adds the
optional explicit terminal evidence described below.

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

## Explicit Shop presentation (T-0274)

`ShopSheet.configure(monetization, ios: bool) -> Error` requires the explicit,
matching IAP/Economy binding. The scene stays unmapped in boot/Nav. `open()` begins
one visit and requests products; it never starts a purchase, consent or ad.

`shop_snapshot() -> Dictionary` returns copied provider prices, durable balance and
entitlement, per-product state, catalog state, purchase state/failure revision,
actual rewarded readiness/pending grant, local-day cap and configured coin amounts.
Only the two canonical IDs with nonblank String prices are offers. Duplicate IDs
fail the entire response closed; provider grant/amount metadata is ignored.
`request_products() -> Error` owns query loading/failure and a finite 120-second
technical watchdog. Query/purchase/recovery dispatch cannot overlap. Late results
without an outstanding query are ignored; the frozen adapter has no catalog request
ID, so a later explicitly requested query accepts its next provider response.

`shop_changed` forwards owner transitions without polling. Synchronous notification
and provider dispatch retain their owner until callbacks return, including listeners
that expire/rebind operations. `begin_shop_visit()` only resets an idle failed ad
offer so the next explicit visit may try again; it performs no provider operation.
No-fill disables the watch action for the current visit. Closed-without-earned ads
leave another explicit attempt available. `request_shop_reward()` binds the actual
Economy and configured grant. An earned failed grant retains that same Callable for
retry without another ad/cap reservation. Another placement's pending reward disables
Shop actions but permits dismissal so its owning caller can settle it.

The view emits purchase/recover/reward/restore intent only. Prices remain opaque
provider-localized strings; amount Labels use config. Owned removal has no action;
the sole purchase Primary moves to the coin pack. Loading blocks buying; offline
uses StatePanel with an explicit catalog retry. Durable coin increases use existing
CurrencyPill count-up, RewardBurst and Toast, never optimistic rewards.
Restore acceptance shows only “purchase check requested”. Actual failure supersedes
that caption (including repeated errors after older failures); no receipt means no
invented “restored”/“nothing to restore”, no aggregate success or endless spinner.
Native SDK activation, physical-device approval and store approval remain open.


## P2b observer receipts (T-0328)

`Events.p2_analytics(name:StringName, params:Dictionary)` carries copied notifications
from the existing service/presentation owners. AnalyticsListener owns a closed event
allowlist and sends through normal Analytics.track validation, consent and durable
FIFO only. Save onboarding, settings, Progress unlocks and Config remain single
producers; no listener decides rewards, navigation, permissions or initialization.

Consent reports require an explicit purpose-specific analytics decision plus known
UMP status. Denial/revocation reaches Analytics before the consent observation;
therefore a denied consent-result event is dropped by the same policy as all other
events. ATT authorization is independent. Enum statuses and bounded failure codes
replace arbitrary provider text.

Ad shown/earned/failure follow accepted presentation callbacks; reward-earned means
the provider callback, not successful wallet settlement. A pending grant retry does
not replay that callback. Rewarded offer notifications follow actual visible enabled
Shop/Hint/x2 controls, once per visit. Interstitial offer follows the policy-approved
dispatch decision. Preload failure may report unavailable without claiming shown.

`StoreTransaction.new(key,product,status,micros=-1,currency="",from_restore=false)` accepts optional
verified provider price and origin metadata. Verified restore updates must set
from_restore=true; overlapping unrelated purchases retain their purchase attribution.
The queue copies all metadata. Never parse localized price
text or derive grants from this metadata. Only a fresh durably processed transaction
with a safe nonnegative integer price and uppercase three-letter currency emits
`iap_purchase_completed`. Missing/invalid metadata skips that observation while
existing grant/acknowledgement behavior continues. Processed-key replay does not
replay completed; telemetry remains best effort across process interruption and does
not add a persistent analytics dedupe ledger. Keys/receipts never enter event params.

`IapAdapter.restore_completed(transactions:Array[StoreTransaction])` is an optional
authoritative final verified nonconsumable batch for a requested restore. Adapters
must suppress duplicate/superseded operations. IapFake snapshots/copies the owned
batch, replays it, and emits terminal evidence only for the still-current successful
operation (including empty success); failed/superseded operations cannot emit it.
Native adapters must implement equivalent evidence before aggregate reporting.

IapFlow observes the current restore without changing gameplay busy/pending/grant
rules. It reports a unique nonconsumable key count only when the terminal batch has
arrived AND every listed key exists in the committed processed-key set. Failed
writes keep observation evidence transiently until the existing explicit settlement
retry succeeds. Restore replay does not become a new purchase-completed event.
Unfinished fetch is not restore, and invalid/consumable batches cannot report success.
No store key or provider price/currency is persisted by this observer change.
