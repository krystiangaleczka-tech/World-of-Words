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

## Application restore results (T-0341)

`Monetization.restore_snapshot() -> Dictionary` and `restore_changed` expose
application state owned by IapFlow, independently of analytics. Fresh snapshots
contain `state:StringName`, `restored_count:int`, `error:Error`, `revision:int`.
Before binding they are unavailable/-1/ERR_UNAVAILABLE/0; the bound flow starts
idle/-1/OK/0. A changed result increments the instance-local revision. No result
is persisted and no caller receives mutable owner containers.

| State | Meaning | Count |
| --- | --- | --- |
| requested | Accepted request, waiting for authoritative provider terminal result | -1 |
| settling | Verified terminal batch exists; some keys lack committed proof | -1 |
| completed | All unique verified nonconsumable keys have committed proof | Unique batch size, including 0 |
| failed | Explicit restore failure or malformed batch | -1 |
| unknown | Provider wait expired without terminal evidence | -1 |

`IapAdapter.restore_failed(error:Error)` is optional authoritative failure for the
current restore only. Adapters must suppress superseded callbacks, as with
restore_completed. IapFake preserves purchase_failed compatibility, then checks its
operation generation again before restore_failed. Generic purchase_failed is never
interpreted as restore failure: an unrelated purchase can fail during a restore.
The first accepted terminal outcome wins; duplicates cannot change its result.

One ALWAYS/ignore-time-scale Timer bounds provider wait to existing
AdPresentation.OPERATION_TIMEOUT_SECONDS. `expire_restore()` uses the same timeout
path; a timeout during the requested notification also prevents stale dispatch.
Timeout does not revoke entitlement or discard valid receipt updates; late batch
results cannot relabel that expired request as successful. A new explicit restore
can start after failure/timeout/completion. Duplicate in-progress restore and
IAP/consent reconfiguration return ERR_BUSY. Existing purchase/catalog/unfinished
policies remain unchanged. Restore notifications guard reentrant commands.

A valid batch stops provider wait, even when durable settlement needs attention.
`retry_restore_settlement() -> Error` drains existing receipts only: no new store
restore/query/fetch/purchase. Failure retains evidence and reports the actual retry
error; existing unfinished recovery may also complete it. Settling retains the
last retry error until completion or another explicit retry result. UI must offer
explicit settlement recovery instead of presenting it as a provider spinner.
The existing Economy grant, committed-key acknowledgement and analytics completion
rules remain authoritative; no save field, product or event is added.

Native adapter activation and correct provider terminal suppression are still
release gates. These interfaces do not certify a real store restore.

## Independent privacy options requirement (T-0343)

`ConsentAdapter.PrivacyRequirement` is UNKNOWN, NOT_REQUIRED or REQUIRED.
`privacy_options_requirement() -> PrivacyRequirement` returns the current provider
observation; the base adapter returns UNKNOWN. The independent
`privacy_options_requirement_changed(requirement:PrivacyRequirement)` signal
reports actual changes, after the getter has been updated. Native adapters must
map authoritative provider privacy-options requirement, default/invalidate to
UNKNOWN when that evidence is unavailable, and suppress duplicate notifications.
Neither UMP State, ATT, analytics permission, calling a form nor its completion
establishes this requirement. UNKNOWN fails closed for future visibility/opening.
A getter read performs no SDK/provider work.

ConsentFake's `set_privacy_options_requirement(requirement:int) -> Error` accepts
only the closed enum and synchronously notifies changes. Invalid values preserve
all state. This observation never cancels/settles pending operations or emits
consent, ATT, failure or analytics decisions; pending tokens remain valid. reset()
retains its existing cancellation/log/control cleanup, restores UNKNOWN and emits
only if the requirement changed. Each instance owns its own observation.

This is additive provider groundwork for T-0288. Monetization still has no privacy
command/result API and Settings still uses its explicit availability/intent hooks.
Service serialization/result/timeout and Settings binding remain follow-up work;
no native adapter, boot activation, endpoint, permission or legal certification is
implied. The existing purpose-specific analytics decision contract is unchanged.

## Service-owned privacy operation (T-0344)

`Monetization.privacy_snapshot() -> Dictionary` returns fresh application state:
`requirement:StringName` (unknown/not_required/required), `available:bool`,
`state:StringName`, `error:Error`, `revision:int`. Availability means the live,
connected, loaded owner has explicit REQUIRED provider evidence, independently of
busy state. `privacy_changed` reports requirement/result transitions with increasing
instance revision. `privacy_owner_matches(save:Node) -> bool` proves exact Save
ownership without requiring IAP. Unconfigured/detached/lost bindings read
unavailable/unknown/false. Configure reads existing provider evidence, resets idle,
and disconnects the old provider; retained exit requires explicit reconfiguration.

`request_privacy_options() -> Error` requires that owner and REQUIRED evidence.
UNKNOWN/NOT_REQUIRED return ERR_UNAVAILABLE; no live binding returns
ERR_UNCONFIGURED. Legal/Continue, ads presentation/earned settlement, IAP busy or
restore settlement, privacy notification/dispatch return ERR_BUSY without replacing
results. Accepted means requested/OK; only the provider's dedicated terminal signal
can report completed/OK or failed/actual error. The operation stops ad readiness;
normal future Continue must re-evaluate its consent gates before initializing ads.
There is no implicit ad/ATT/Continue/store operation on acceptance or completion.

`ConsentAdapter.privacy_options_completed(error:Error)` is optional authoritative
terminal evidence for the current show_privacy_options operation. OK means form
completion, never analytics or ad consent. Providers must suppress duplicates and
obsolete callbacks. Legacy adapters without it time out. ConsentFake preserves its
legacy consent_resolved/operation_failed notification, then checks its generation
again before dedicated terminal: known UMP outcome -> OK, unknown -> ERR_INVALID_DATA,
error -> FAILED. Reentrant supersession/reset prevents an obsolete terminal.

Generic consent updates during privacy update UMP evidence without ending the form,
opening another form, requesting ATT or initializing ads. Generic operation_failed
alone cannot identify privacy completion. Requirement changes do not cancel/settle
work. `expire_privacy_options() -> void` and the existing legal watchdog finish only
a pending privacy operation as unknown/ERR_TIMEOUT and stop analytics relay. The
same one-shot 120-second ALWAYS/ignore-time-scale timer is reused; no extra config
or polling. Expiry from requested notification prevents stale provider dispatch.
First terminal wins; late results outside requested cannot relabel it. A subsequent
explicit retry dispatches once if still required, with adapter token suppression.

Pending privacy and synchronous notification/dispatch reject configure/configure_iap,
start_session, before_next_level, purchase, restore_purchases, unfinished recovery,
product query, rewarded/Shop reward and restore settlement retry with ERR_BUSY.
This guard remains active through terminal callbacks. Existing nonprivacy behavior
is preserved; incoming verified receipts keep their existing settlement path.

Only explicit analytics_resolved decisions relay Events.consent_changed, including
privacy before start_session. Form results, UMP, ATT and requirement never imply a
purpose decision. A successful close allows the provider's explicit decision after
closing; failure/timeout stops relay. No new analytics event or persisted consent
is added. Settings binding, boot/Nav activation, native callback correlation/provider
mapping and device/legal certification remain follow-up gates.
