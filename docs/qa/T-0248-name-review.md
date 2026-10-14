# T-0248 irreversible-name review and inventory

Opinion: PASS for the current irreversible names, with downstream integration requirements below.
Reviewer: current Codex/GPT assistant, self-authored at the owner's explicit request on 2026-10-14.
This is neither an Opus opinion nor an independent second opinion.

Audited source: `e3fe760acbb5af3ac549645d817994347b84b670` (merged T-0246; includes T-0247).
No names, runtime behavior, SDKs, store products or provider settings are changed by this packet.

## Review scope

Read AGENTS.md, PRODUCT core-events/IAP catalog/config requirements, decision0009 and the files
below. Assess reserved names, reporting semantics, sensitive payloads, units,
namespace boundaries and irreversible product IDs. Return PASS or findings with severity,
source/line and a concrete recommendation. Distinguish blockers from future integration checks.
Do not certify current vendor/store policy or external account state without actual evidence.

## Source fingerprint

| File | SHA-256 |
|---|---|
| `game/data/analytics/ads.json` | `6e309b16c669640675f4ceaca93eb90c4b8356849e715d94b62b78ed24edfbb0` |
| `game/data/analytics/consent.json` | `feff62669f6efbe8e1a8e607a9ae0fb2acf9e6720c5be9403a22390d6033906d` |
| `game/data/analytics/daily.json` | `9c2aa34b61af679ad859571c8beb5e23b0adba75e8b87356e9bb296c7a588aeb` |
| `game/data/analytics/economy.json` | `966e8b4e6bd727191281aac5252047cd66f9fb09e328447c4c2ff093e0d3f0c8` |
| `game/data/analytics/iap.json` | `409a4a7051c352780f0cde75e08a25edab66c68e3df34ad2d9d453248a42579f` |
| `game/data/analytics/level.json` | `48543b558ea0160f7c48d8ef7bc82df27a29eba790aaf38bfeed436d31f482fb` |
| `game/data/analytics/lifecycle.json` | `89170fca79ee13f0f976a8ca7683a5ca82ca3d3afbcba87f5fa47ea00a212afe` |
| `game/data/analytics/meta.json` | `4bd3f4f3744131fc5359bb43af1486bbafcffe4e7f39a539eac5717f71974a54` |
| `game/data/analytics/onboarding.json` | `f1787c34466ae9859043b61681ed0016e3bd1af4b443a8cfc2e5a5ac279b373e` |
| `game/data/analytics/system.json` | `c24285ed258d15ef7f35b12dcf0f769c7e7094b8b28244552f46738b80f9b19f` |
| `game/data/analytics/tools.json` | `496e940d3e12980691616083e81a6d8f92864dfb8c0c18ddf77ccaa6d46b8732` |
| `game/data/config/ads.json` | `296b39a3a596ed0689b6139722baf70887af59b0497b29d0b411184e6fc2bc2b` |
| `game/data/config/bonus.json` | `f6bebde738b5dfae5fa54ea64046d7e42aa112bf5698d611375b2aa6a944edce` |
| `game/data/config/consent.json` | `f16fff60b4f18dfb4f3205612df0013661e48de7054ae2dc70dad8204d221386` |
| `game/data/config/economy.json` | `0a305d23b86558ab3acd69a9fecbb5fa3187488117fa7f16c1c4b78db1e5a362` |
| `game/data/config/hint.json` | `6b557c858d986b4253e28104250b1149ee9f22019f14d0050c4eb5333a0ef479` |
| `game/data/config/iap.json` | `a0966cd5952b1d6a04718244735e97ae5d38c314f285b59f0c16d06f2351dc0e` |
| `game/data/config/meta.json` | `69ff2dadd6758b87bbca3c493d306a1a9b7cd0393191935659c8a37dd4da74c4` |
| `game/data/config/onboarding.json` | `1123cb64b7b74819c2e27dee7166336442a4ad44faabddf81cb9128bbf4c3686` |
| `game/data/config/unlocks.json` | `8e0ae7ac163a4c7c938bdfcc4908f5c6ba5113c35c154bf6b415b1b624cf462b` |
| `game/services/analytics/analytics_registry.gd` | `a4a7c0aed60ee049581ef51ba3193fa8cf01b0b04065e19fd2b08904663bbf57` |
| `game/services/analytics/registry.schema.json` | `72b9012f7fe44eb5a99c43c6d019ddab8aaa9a95b82a68b901d7767a29dc9120` |
| `docs/PRODUCT.md` | `9617f966bb0ec9dca44816fcc3d49d66d42c0af349f40b2a96c8960c0bf4e969` |
| `docs/decisions/0009-platform-providers.md` | `a2ceaba99ba277727c749765ed8ce01a4998a8431c88a052690ffd37ce44ca56` |

## Analytics inventory

47 event definitions, event-specific params only. T-0250 owns the common envelope and consent/
queue work; availability of a definition does not authorize collection. P3 daily contracts are inert.

| Area | Event | Parameters | Meaning |
|---|---|---|---|
| ads | `ad_offer_shown` | `placement:string`, `ad_format:string` | Ad placement offered; format is rewarded or interstitial |
| ads | `ad_shown` | `placement:string`, `ad_format:string` | Ad displayed after permitted initialization |
| ads | `ad_reward_earned` | `placement:string` | Provider reward-earned callback received |
| ads | `ad_failed` | `placement:string`, `ad_format:string`, `error_code:string` | Ad unavailable/failed; bounded provider code, never exception text |
| consent | `consent_result` | `analytics_allowed:bool`, `ads_allowed:bool`, `status:string` | Resolved consent decisions; status is a bounded provider code |
| consent | `att_result` | `status:string` | Resolved ATT authorization status code |
| daily | `daily_start` | `date:string`, `level_id:string` | P3 daily puzzle entered; local calendar date |
| daily | `daily_complete` | `date:string`, `duration_ms:int` | P3 daily puzzle completed; elapsed milliseconds |
| daily | `calendar_month_complete` | `month:string` | P3 local calendar month completed |
| daily | `streak_updated` | `date:string`, `length:int` | P3 streak updated for local day |
| daily | `streak_freeze_used` | `date:string` | P3 streak freeze consumed for local day |
| daily | `streak_broken` | `date:string`, `length:int` | P3 previous streak ended |
| daily | `streak_repaired` | `date:string`, `length:int` | P3 streak durably repaired |
| economy | `economy_grant` | `reason:string`, `coins:int`, `hint:int`, `reveal:int` | Committed grant; nonnegative integer component amounts |
| economy | `economy_spend` | `reason:string`, `coins:int`, `hint:int`, `reveal:int` | Committed spend; nonnegative integer component amounts |
| economy | `bonus_chest_opened` | `slot:int`, `chests:int`, `coins:int` | Completion-boundary chest count and configured coin payout |
| iap | `shop_opened` | `origin:string` | Shop opened from a named UI origin |
| iap | `iap_purchase_started` | `product_id:string` | Store purchase requested for canonical product |
| iap | `iap_purchase_completed` | `product_id:string`, `price_micros:int`, `price_currency:string` | Purchase durably granted; provider price in millionths and ISO currency, no receipt/token |
| iap | `iap_purchase_failed` | `product_id:string`, `error_code:string` | Purchase failed/cancelled; bounded provider code only |
| iap | `iap_restore_completed` | `restored_count:int` | Nonconsumable restore completed; no provider transaction identity |
| level | `level_start` | `slot:int`, `level_id:string` | Entered campaign level |
| level | `level_complete` | `slot:int`, `level_id:string`, `duration_ms:int`, `hints_used:int`, `reveals_used:int`, `bonus_words:int`, `stars:int` | Durably completed level; elapsed milliseconds and earned statistics |
| level | `word_found` | `slot:int`, `level_id:string`, `word:string` | New required word found |
| level | `bonus_word_found` | `slot:int`, `level_id:string`, `word:string` | New eligible bonus word found |
| level | `invalid_word_submitted` | `language:string`, `slot:int`, `letters:string` | Submitted letter string for dictionary repair; language and slot captured at attempt |
| level | `already_found_word` | `slot:int`, `level_id:string`, `word:string`, `kind:string` | Repeated required or bonus word; kind is level or bonus |
| lifecycle | `app_boot` | (none) | Application process boot |
| lifecycle | `app_foreground` | (none) | Application returns to foreground |
| lifecycle | `app_background` | (none) | Application moves to background |
| lifecycle | `nav_screen` | `screen:string` | Navigation enters a screen |
| meta | `stars_earned` | `slot:int`, `stars:int` | Durably earned stars at completion |
| meta | `postcard_piece_revealed` | `location_id:string`, `pieces:int` | Durably revealed postcard piece count |
| meta | `location_complete` | `location_id:string` | Location postcard durably completed |
| meta | `region_complete` | `region_id:string` | Region durably completed |
| onboarding | `onboarding_step` | `step:int` | Reached onboarding step |
| onboarding | `feature_unlocked` | `feature:string`, `slot:int` | Durably unlocked feature at campaign slot |
| system | `settings_changed` | `setting:string` | Named setting durably changed; no arbitrary setting value |
| system | `save_corrupted` | `schema_version:int` | No valid save recovered; version is zero if unknown |
| system | `save_migrated` | `from_version:int`, `to_version:int` | Save schema upgraded without retroactive grants |
| system | `remote_config_applied` | `config_version:string` | Validated remote configuration activated |
| system | `experiment_assigned` | `experiment_id:string`, `bucket:int` | Deterministic experiment bucket assigned |
| system | `content_version_loaded` | `content_version:int` | Validated content version loaded |
| tools | `hint_used` | `slot:int`, `payment:string` | Hint applied; payment is item, coins or rewarded |
| tools | `reveal_used` | `slot:int`, `payment:string` | Whole-word Reveal applied; payment is item or coins |
| tools | `shuffle_used` | `slot:int` | Wheel positions shuffled |
| tools | `hint_stuck_offer_shown` | `slot:int`, `trigger:string` | Once-per-level hint offer; trigger is idle or invalid_streak |

## Config inventory

35 definitions; remote flags below describe shipped definitions, not a certified remote-config
integration. Defaults/ranges are recorded as review inputs, with no proposed balance changes.

| Area | Key | Type | Default | Range | Remote | Owner |
|---|---|---|---|---|---|---|
| ads | `ads.interstitial.first_slot` | int | `16` | `[1, 200]` | false | Chris |
| ads | `ads.interstitial.min_levels_between` | int | `4` | `[1, 20]` | false | Sol |
| ads | `ads.interstitial.min_seconds_between` | int | `180` | `[30, 1800]` | false | Sol |
| ads | `ads.interstitial.session_grace_seconds` | int | `120` | `[0, 1800]` | false | Sol |
| ads | `ads.interstitial.purchase_grace_levels` | int | `10` | `[0, 100]` | false | Sol |
| ads | `ads.rewarded.hint.enabled` | bool | `true` | `null` | false | Chris |
| ads | `ads.rewarded.double.enabled` | bool | `true` | `null` | false | Chris |
| ads | `ads.rewarded.shop_coins.daily_cap` | int | `3` | `[0, 20]` | false | Sol |
| bonus | `bonus.chest.words_required` | int | `10` | `[1, 100]` | false | Sol |
| consent | `consent.ump_after_slot` | int | `1` | `[1, 20]` | false | Chris |
| consent | `consent.att_after_slot` | int | `6` | `[1, 20]` | false | Chris |
| economy | `economy.reward.level_complete` | int | `25` | `[0, 1000]` | false | Sol |
| economy | `economy.reward.double_multiplier` | int | `2` | `[1, 5]` | false | Sol |
| economy | `economy.reward.bonus_chest` | int | `100` | `[0, 5000]` | false | Sol |
| economy | `economy.reward.rewarded_hint` | int | `1` | `[1, 5]` | false | Sol |
| economy | `economy.reward.rewarded_coins` | int | `100` | `[0, 5000]` | false | Sol |
| economy | `economy.reward.daily` | int | `100` | `[0, 5000]` | false | Sol |
| economy | `economy.grant.onboarding_hints` | int | `3` | `[0, 20]` | false | Chris |
| economy | `economy.price.hint` | int | `100` | `[1, 10000]` | false | Sol |
| economy | `economy.price.reveal` | int | `250` | `[1, 10000]` | false | Sol |
| economy | `economy.journal.max_entries` | int | `200` | `[50, 2000]` | false | Sol |
| hint | `hint.offer_idle_seconds` | int | `45` | `[10, 600]` | false | Sol |
| hint | `hint.offer_invalid_streak` | int | `5` | `[2, 50]` | false | Sol |
| iap | `iap.coins_s.amount` | int | `1000` | `[1, 100000]` | false | Chris (Q6) |
| meta | `meta.stars.per_level` | int | `1` | `[1, 3]` | false | Chris |
| meta | `meta.postcard.pieces` | int | `4` | `[1, 16]` | false | Chris |
| meta | `meta.postcard.piece_star_cost` | int | `12` | `[1, 100]` | false | Sol |
| onboarding | `onboarding.max_prompts_per_session` | int | `1` | `[0, 5]` | false | Chris |
| unlocks | `unlocks.shuffle_slot` | int | `2` | `[1, 50]` | false | Chris |
| unlocks | `unlocks.bonus_meter_slot` | int | `5` | `[1, 50]` | false | Chris |
| unlocks | `unlocks.hint_slot` | int | `7` | `[1, 50]` | false | Chris |
| unlocks | `unlocks.journey_slot` | int | `10` | `[1, 50]` | false | Chris |
| unlocks | `unlocks.reveal_slot` | int | `12` | `[1, 50]` | false | Chris |
| unlocks | `unlocks.double_reward_slot` | int | `12` | `[1, 50]` | false | Chris |
| unlocks | `unlocks.daily_slot` | int | `15` | `[1, 100]` | false | Chris |

## Canonical IAP proposal (verbatim PRODUCT catalog)

Product ID convention (proposal, Chris approves): `<type>.<item>.v<N>`, lowercase letters, digits,
underscores and periods only; `nc` = non-consumable, `c` = consumable. No app name in IDs (the store
name is not final). A changed product (content or price tier strategy) gets a new `v<N>` id.

Product IDs are irreversible: once created in Google Play Console or App Store Connect they cannot be
reused after deletion. Create them only after Chris approves this table (verify current store ID
rules at creation time).

| Product ID | Type | Phase | Content |
|---|---|---|---|
| `nc.remove_forced_ads.v1` | non-consumable | P2 | Disables interstitials permanently; restorable |
| `c.coins_s.v1` | consumable | P2 | `iap.coins_s.amount` coins |
| `c.coins_m.v1` | consumable | P3 | `iap.coins_m.amount` coins |
| `c.coins_l.v1` | consumable | P3 | `iap.coins_l.amount` coins |
| `c.starter_pack.v1` | consumable, one purchase per install enforced in game | P3 | coins + Hint + Reveal items only (no entitlements, so restore is not needed) |

Price points are Chris's decision per store. Research reference for Poland: Remove Forced Ads around
24.99 PLN (Words of Wonders charges about 49.99 PLN), small coin pack 4.99 PLN, starter pack 9.99 PLN.

## Reviewed considerations

- Analytics must equal the 47 PRODUCT names exactly. Existing tests cover typed payloads,
  atomic append/copy isolation and runtime/schema pattern parity. These do not establish that
  every future producer emits correct domain values or applies consent.
- Provider naming restrictions are frozen at the T-0247 policy snapshot (2026-10-13); check the
  Firebase mobile-event/custom-parameter policy and preserve automatic/custom event separation.
- `price_micros` is an integer in millionths and `price_currency` avoids reserved custom
  `currency`; later provider mapping must preserve purchase/revenue meaning and deduplication.
- `invalid_word_submitted` includes language/slot/letters for dictionary repair. Producers must
  remain bounded to game input, with consent and retention controls; no raw exception/receipt
  or advertising-identifier fields appear in the event-specific catalog.
- Config keys are dotted by subsystem; event names are lower snake_case; IAP IDs encode type,
  item and version without the unsettled store name. Check semantic ambiguity and future migration cost.
- The starter pack is a future P3 consumable with per-install gating, not a restorable entitlement.
  Confirm that this intended store identity/gating distinction is acceptable before product creation.

## Owner authorization and method

Chris requested "Zrób samemu opinie" after being told T-0248 specifies Opus and the environment
cannot supply it. That is the explicit selection of this assistant and a checkpoint-specific
waiver of independence for the primary opinion. Earlier decision0010 is not extended. The fresh
independent PR-quality review remains separate and does not become an Opus opinion.

Reviewed the exact 24 fingerprinted source files, PRODUCT core-event/IAP requirements, GAME_DESIGN
config namespace/default table, runtime/schema naming guards and the existing registry tests.
Compared all 47 unique events with PRODUCT; verified all 35 config entries use their area prefix,
and all five IAP IDs match the canonical catalog and version/type convention.

Also retrieved Google's official naming reference on 2026-10-14:
https://support.google.com/analytics/answer/13316687?hl=en, Mobile (Android and iOS) subsection.
Response SHA-256: `a73d96cb55b56db51ac629e1c8cdf3570cac80027a10b2f7fcd0f38290a1661d`.
The documented reserved mobile-event/custom-reporting parameter lists match the frozen guard;
`screen_view` and `ad_impression` are additionally blocked by this project's policy. The current
reference also reserves the parameter prefix `gtag.`; the allowed snake_case pattern already
rejects a period. This review is of source and public naming rules, not a provider-account test.

## Opinion and dispositions

PASS for the current event names, IAP IDs and shipped config namespaces. No critical/high/medium
rename blocker was found. Preserve the names: a gratuitous rename would break future history or
store identity without solving a present conflict. The following low-severity integration findings
are requirements for the already-planned downstream tasks, not completed runtime evidence.

| ID / severity | Finding and reason | Disposition / owner task |
|---|---|---|
| N1 / low | `iap_purchase_completed` is a custom business event, not proof that Firebase's built-in revenue dashboard will recognize a purchase. `price_currency` avoids a reserved custom reporting dimension; that does not prohibit `currency` in a provider's recommended purchase payload. | Preserve business names/fields. T-0252 must explicitly map purchase semantics, units and provider automatic/custom tracking; T-0271 must prevent duplicate committed grants. Verify exactly one counted purchase before release, without assuming a custom name populates standard revenue reports. |
| N2 / low | Strict primitive types do not enforce bounded `reason`, `status`, `payment`, `kind`, `trigger` or `error_code` values. Invalid letters are game-input telemetry; the schema alone cannot establish privacy safety. | T-0250/T-0251 and provider producers must enforce bounded codes, game-origin letter strings, consent and no raw exceptions/receipts/identifiers. Keep FR-ANL-04 language/slot/letters; do not treat registry availability as permission to collect. |
| N3 / low | Durable meta/economy names and descriptions are suitable, but names alone do not specify once-only emission or distinguish a cumulative `pieces` count from a newly revealed delta. | T-0251 must derive side effects from committed progression, emit once per committed effect and retain `pieces` as the documented persisted count; analytics must not award progress. T-0252 must avoid double-counting automatic ad events as custom `ad_shown`. |
| N4 / low | `nc.remove_forced_ads.v1` clearly identifies a permanent, restorable nonconsumable; the coin IDs correctly identify consumables. The future starter-pack rule is per install, so a new install may qualify again. This is consistent with PRODUCT, but is not an account-wide once-ever promise. | Keep all five IDs. T-0268 approves catalog/price points; T-0272/T-0273 validate actual store product types/ID rules before creation. Preserve the declared P3 per-install policy in its future implementation; no products are created or prices approved here. |
| N5 / low | All 35 shipped dotted keys have unique area ownership and match the GAME_DESIGN table. `analytics.queue.max_events`, `config.remote.timeout_ms` and further P3 pack/streak keys are documented future names, not currently loaded entries. All shipped remote flags are false. | T-0250 registers its queue key and T-0254/T-0255 register remote-config requirements in bounded scope; future P3 tasks add their keys without renaming current ones. Review remote eligibility explicitly; consent/unlock boundaries must not become remotely weakened. |

No runtime or canonical-name remediation is needed in this documentation task. No assumption that
store products exist, SDK integration works, consent is certified or release is approved is made.
T-0248's named-reviewer checkpoint is satisfied by the explicit owner-selected self-authored opinion;
T-0249/T-0268 may use its merged completion only after ordinary PR review and CI. Their other
prerequisites and their actual provider/store work remain unchanged.

T-0247 was already merged as d16fa90; its status is reconciled to done in this documentation task.

## Validation

All 24 source hashes,47 event definitions and35 config entries verified against the unchanged
source. Existing full `make check` on this same production/test tree passed:612/612 Godot tests,
329 pipeline tests,500 tools tests, registries/content/UI/token/generated-theme checks. The later
changes are Markdown report/task updates only; task/scope/inventory validation is rerun for the final
candidate and fresh exact-head PR-quality review/all14CI remain required before merge.
