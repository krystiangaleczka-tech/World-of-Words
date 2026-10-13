# T-0247 typed analytics catalog

Next ready roadmap contract on main531cc67; T-0242–T-0246 remain blocked by the unfinished atomic
Save/Economy prerequisites. T-0203 and T-0033 are done. PRODUCT core-event seed is the canonical
name source; the catalog includes exactly47 names across11 area files. Existing lifecycle file is
byte-unchanged. P3 daily entries define future schemas only, without runtime activation.

Only event-specific params are declared here. T-0250 owns consent, durable bounded queue and common
install_id/app/content/language/bucket envelope; T-0251/T-0328 own mapping and semantic context.
Descriptions constrain producer meaning; primitive validation is not an enum/domain validator.
No new Events signals, SDKs, tracking calls or collection/sending behavior are introduced.
Fake-only queue remains explicitly configured and keeps its prior behavior.

Provider naming policy is frozen on2026-10-13 from Google's mobile naming rules:
https://support.google.com/analytics/answer/13316687?hl=en (Mobile Android/iOS subsection).
Runtime and JSON schema reject the documented reserved mobile events and custom-reporting parameter
names, provider prefixes, and names beyond40characters. PROJECT's PRODUCT examples screen_view and
automatic ad_impression are additionally protected. This policy concerns our custom names, not a
claim that provider auto-events are disabled. No network access is used in tests.

Invalid-word dictionary repair includes language/slot/letters explicitly (FR-ANL-04). Durations are
integer milliseconds; economy deltas are integer coins/hint/reveal components; IAP prices use integer
millionths and ISO price_currency (custom-reporting currency name is reserved). No raw receipt,
provider transaction token/identity, advertising identifier, personal data field or exception-text
payload is introduced. Error/status/reason strings must be bounded producer/provider codes, not raw
messages. Tracking eligibility, value validation and source context remain listener/service tasks.

T-0248 Opus review of irreversible names is still a separate pre-release gate. This task neither
runs that gate nor certifies production Firebase integration or consent compliance.

## Event-specific payloads

| Event | Parameter:type | Meaning |
|---|---|---|
| `ad_offer_shown` | placement:string, ad_format:string | Ad placement offered; format is rewarded or interstitial |
| `ad_shown` | placement:string, ad_format:string | Ad displayed after permitted initialization |
| `ad_reward_earned` | placement:string | Provider reward-earned callback received |
| `ad_failed` | placement:string, ad_format:string, error_code:string | Ad unavailable/failed; bounded provider code, never exception text |
| `consent_result` | analytics_allowed:bool, ads_allowed:bool, status:string | Resolved consent decisions; status is a bounded provider code |
| `att_result` | status:string | Resolved ATT authorization status code |
| `daily_start` | date:string, level_id:string | P3 daily puzzle entered; local calendar date |
| `daily_complete` | date:string, duration_ms:int | P3 daily puzzle completed; elapsed milliseconds |
| `calendar_month_complete` | month:string | P3 local calendar month completed |
| `streak_updated` | date:string, length:int | P3 streak updated for local day |
| `streak_freeze_used` | date:string | P3 streak freeze consumed for local day |
| `streak_broken` | date:string, length:int | P3 previous streak ended |
| `streak_repaired` | date:string, length:int | P3 streak durably repaired |
| `economy_grant` | reason:string, coins:int, hint:int, reveal:int | Committed grant; nonnegative integer component amounts |
| `economy_spend` | reason:string, coins:int, hint:int, reveal:int | Committed spend; nonnegative integer component amounts |
| `bonus_chest_opened` | slot:int, chests:int, coins:int | Completion-boundary chest count and configured coin payout |
| `shop_opened` | origin:string | Shop opened from a named UI origin |
| `iap_purchase_started` | product_id:string | Store purchase requested for canonical product |
| `iap_purchase_completed` | product_id:string, price_micros:int, price_currency:string | Purchase durably granted; provider price in millionths and ISO currency, no receipt/token |
| `iap_purchase_failed` | product_id:string, error_code:string | Purchase failed/cancelled; bounded provider code only |
| `iap_restore_completed` | restored_count:int | Nonconsumable restore completed; no provider transaction identity |
| `level_start` | slot:int, level_id:string | Entered campaign level |
| `level_complete` | slot:int, level_id:string, duration_ms:int, hints_used:int, reveals_used:int, bonus_words:int, stars:int | Durably completed level; elapsed milliseconds and earned statistics |
| `word_found` | slot:int, level_id:string, word:string | New required word found |
| `bonus_word_found` | slot:int, level_id:string, word:string | New eligible bonus word found |
| `invalid_word_submitted` | language:string, slot:int, letters:string | Submitted letter string for dictionary repair; language and slot captured at attempt |
| `already_found_word` | slot:int, level_id:string, word:string, kind:string | Repeated required or bonus word; kind is level or bonus |
| `app_boot` | (none) | Application process boot |
| `app_foreground` | (none) | Application returns to foreground |
| `app_background` | (none) | Application moves to background |
| `nav_screen` | screen:string | Navigation enters a screen |
| `stars_earned` | slot:int, stars:int | Durably earned stars at completion |
| `postcard_piece_revealed` | location_id:string, pieces:int | Durably revealed postcard piece count |
| `location_complete` | location_id:string | Location postcard durably completed |
| `region_complete` | region_id:string | Region durably completed |
| `onboarding_step` | step:int | Reached onboarding step |
| `feature_unlocked` | feature:string, slot:int | Durably unlocked feature at campaign slot |
| `settings_changed` | setting:string | Named setting durably changed; no arbitrary setting value |
| `save_corrupted` | schema_version:int | No valid save recovered; version is zero if unknown |
| `save_migrated` | from_version:int, to_version:int | Save schema upgraded without retroactive grants |
| `remote_config_applied` | config_version:string | Validated remote configuration activated |
| `experiment_assigned` | experiment_id:string, bucket:int | Deterministic experiment bucket assigned |
| `content_version_loaded` | content_version:int | Validated content version loaded |
| `hint_used` | slot:int, payment:string | Hint applied; payment is item, coins or rewarded |
| `reveal_used` | slot:int, payment:string | Whole-word Reveal applied; payment is item or coins |
| `shuffle_used` | slot:int | Wheel positions shuffled |
| `hint_stuck_offer_shown` | slot:int, trigger:string | Once-per-level hint offer; trigger is idle or invalid_streak |

## Validation

Four new GUT tests cover all47 exact typed payloads and missing/extra/wrong-type rejection, atomic
reserved-name rejection/boundaries, invalid-word context and purchase fields, isolated definitions/
queued payloads and absence of adapter calls before explicit Fake flush. Twelve Python cases verify
independent PRODUCT coverage, unchanged lifecycle, runtime/schema pattern parity, provider rules and
boundaries, including terminal newlines. Existing shipped event-count oracle updates4→47; assertions otherwise retained.
Pinned4.7.2 GUT485/485 and full make check, task/scope checks, fresh exact-head independent review
and14CI required before merge. No actual provider account, credentials, SDK or network endpoints added.
