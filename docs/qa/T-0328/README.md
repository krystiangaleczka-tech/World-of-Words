# T-0328 — P2b analytics receipt matrix

| Canonical events | Single producer / evidence |
| --- | --- |
| consent_result | Monetization, explicit analytics-purpose decision AND known UMP status; permission update precedes observation |
| att_result | Monetization, accepted authorized/denied/restricted callback for its active ATT operation |
| ad_offer_shown | Actual visible enabled Shop/hint/x2 controls, once per visit; approved interstitial dispatch decision |
| ad_shown / ad_reward_earned / ad_failed | AdPresentation's accepted opened/earned/failure/timeout callbacks; duplicate/stale callbacks ignored by existing state guards |
| shop_opened | Actual Shop catalog opening; alternative content and repeated refresh/open are excluded |
| iap_purchase_started / iap_purchase_failed | IapFlow's accepted purchase and bounded failed/cancelled/timeout state observations |
| iap_purchase_completed | Fresh durable processed-key proof plus frozen verified safe price/currency; restored or already-processed transactions are excluded |
| iap_restore_completed | Explicit terminal verified nonconsumable batch AND every unique key durably processed; failed-write evidence waits for the existing explicit retry |
| onboarding_step | Existing Save commit receipt, newly observed by AnalyticsListener; no presentation callback or speculative write |
| hint_stuck_offer_shown | Existing once-per-Level presentation, bridged through its injected Events bus with actual slot and trigger |
| settings_changed / feature_unlocked | Existing listener and committed Save/Progress signals, preserved as single producers |
| remote_config_applied / experiment_assigned | Existing Config-owned reporting, preserved without a second listener mapping |

Events.p2_analytics is side effects only. AnalyticsListener admits a closed event allowlist with bounded status/placement/error values and routes only through Analytics.track's registry validation, consent and durable FIFO. Observation failures/full queues/denial never decide grants, SDK calls, permissions or navigation. No event registry/schema or persisted save format changes.

StoreTransaction's optional verified price and restored-origin metadata are copied through both Fake and IapFlow. Localized prices remain display data, never parsed for analytics. Unknown/invalid metadata suppresses purchase completion telemetry while settlement and provider finish continue. A simultaneous ordinary purchase retains its own attribution during a restore. Terminal batches are provider evidence, not inferred from restore command acceptance, fetch-unfinished or individual callbacks. Legacy/native adapters without that evidence cannot claim aggregate success; native integration and device/dashboard proof remain blocked on their own external prerequisites.

All error codes/statuses are bounded; no provider error text, receipt or store key enters the event payload. Telemetry is best effort around process interruption; this task adds no persistent telemetry dedupe ledger and no replay that might grant twice. It does not alter existing grant/price/prompt/consent logic, activate SDKs, configure accounts or add endpoints/secrets/dependencies.

Focused GUT: 23 tests / 459 assertions. Tests cover runtime consent/FIFO behavior, rejected ingress and listener teardown, failed onboarding write/retry, existing settings/unlock uniqueness, actual visible Shop/hint/x2 and stuck offers, approved interstitial proof, duplicate ad callbacks, failed reward-write retry, early close, bounded failures/timeouts including synchronous expiration from the failure observer, fresh/duplicate/pending/cancelled/failed IAP, frozen/absent/invalid prices, restore empty/nonconsumable/duplicate/failed-write proof, overlapping purchase attribution, a late verified callback after Save teardown, and full/unknown/denied queues with successful business results. Existing Config telemetry regression remains unchanged.

Full make check, independent pack review and exact-head CI results are recorded in the PR. The native CI gallery artifact exercises all 180 current page/layout/PL-PSEUDO/theme variants; screenshots verify the existing catalog compositions, not reference-device behavior or provider delivery. There are no visual/copy/theme changes in this task.
