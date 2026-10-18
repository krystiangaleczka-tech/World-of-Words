# T-0258 — Firebase Analytics funnels F1–F3 and device QA packet

Status: **PREPARED / NOT EXECUTED** (human task; do not label as passed).
Owner: Chris. Date prepared: 2026-10-15.
Sources: `docs/PRODUCT.md#analytics-and-kpis`, `#funnels`,
`game/data/analytics/*.json`, `docs/TESTING.md#reference-devices`,
`docs/decisions/0009-platform-providers.md`.

## Preconditions — block execution until met

- [ ] T-0253 real crash adapter and T-0328 P2b listener are merged and verified.
- [ ] T-0252 Firebase Analytics real adapter is installed, configured and verified with
      real Android/iOS builds; a Fake cannot prove dashboard delivery.
- [ ] Consent purpose and collection rules (Q7/FR-CONSENT-02) are approved.
- [ ] Test build SHA, app/content versions and analytics property/project are recorded.
- [ ] Chris has Firebase/GA4 property permissions and a sandbox test purchase path.
- [ ] A unique **test environment**, test cohorts and non-production devices are selected;
      no real purchaser transaction, device ID, email, advertising ID or receipt is attached.

Only test under actual consent authorization. A user denying analytics consent must
**not** be treated as an absent/failing funnel participant: such events are
intentionally not sent.

## Register exact events and dimensions

Provider: Firebase Analytics → linked GA4 property. Do not rename canonical
`game/data/analytics/*.json` event names or add telemetry inside this human task.

Common context already defined by T-0250: `install_id`, `app_version`,
`content_version`, `language`, `experiment_buckets` (JSON string).
Check these values on permitted DebugView events; do not export raw identifiers
into this repository. The `install_id` is an internal random UUID, not a
substitute for the GA4 user identity.

| Registered event | Parameter required for checks | Type |
|---|---|---|
| `app_boot`, `app_foreground`, `app_background` | common context only | — |
| `level_complete` | `slot`, `level_id`, `duration_ms`, `hints_used`, `reveals_used`, `bonus_words`, `stars` | int, string, int × 5 |
| `consent_result` | `analytics_allowed`, `ads_allowed`, `status` | bool, bool, string |
| `hint_stuck_offer_shown` | `slot`, `trigger` | int, string |
| `hint_used` | `slot`, `payment` | int, string |
| `ad_offer_shown` | `placement`, `ad_format` | string, string |
| `ad_reward_earned` | `placement` | string |
| `shop_opened` | `origin` | string |
| `iap_purchase_started` | `product_id` | string |
| `iap_purchase_completed` | `product_id`, `price_micros`, `price_currency` | string, int, string |

`product_id` must come from the canonical store catalogue. `placement`
must be verified against actual emitted values before filtering — never invent
or silently normalize values. Do not send transaction IDs or purchase receipts.

**GA4 reporting gate:** the Android/iOS `slot` event parameter is an integer.
GA4 documentation warns that numeric app event parameters are not parsed as
event-scoped custom dimensions. Therefore **do not claim that a `slot`-filtered
F1 dashboard funnel works merely because `level_complete` appears in DebugView**.
First verify that GA4 Funnel exploration allows exact filtering on the raw
numeric event parameter with this SDK/property. If it does not, record
`BLOCKED: numeric slot filter` and escalate for a separately authorized
reporting solution (for example an approved BigQuery event-parameter query,
or a separate schema change task). Do not silently change `slot` to a string:
the analytics registry requires `int`.

## F1 — Onboarding

Create a **closed, ordered** GA4 Funnel exploration (indirect transitions allowed;
other legitimate events occur between stages). Onboarding slot values are event
parameters, **not** different `level_complete` event names.

| # | Step | Predicate |
|---|---|---|
| 1 | First boot | `app_boot`; use fresh-install test cohort |
| 2 | Complete slot 1 | `level_complete` with `slot = 1` |
| 3 | Consent decision | `consent_result` only when analytics collection is permitted |
| 4 | Complete slot 3 | `level_complete` with `slot = 3` |
| 5 | Complete slot 5 | `level_complete` with `slot = 5` |
| 6 | Complete slot 7 | `level_complete` with `slot = 7` |
| 7 | Complete slot 10 | `level_complete` with `slot = 10` |
| 8 | Complete slot 15 | `level_complete` with `slot = 15` |
| 9 | Day-1 return | `app_boot` on day 1 **only if day-1 cohort restriction is verifiable** |

The ninth predicate is not an unrestricted second boot: a same-day relaunch
is **not** D1 retention. Report onboarding completion through slot 15,
and **separately** verify a local-day-1 returning-install cohort from
`app_boot`/`app_foreground`. If the provider cannot express the exact
cohort restriction in the funnel, do not present step 9 as D1.

A consent-denied install correctly generates no provider-side post-decision
analytics; it is excluded from this measured consenting cohort, not counted
as a product abandonment. Record its privacy QA separately.

## F2 — Hint conversion

Create two mutually understandable journey views, **not one mandatory chain
that treats paid/free hints as failures**:

- **F2 direct:** `hint_stuck_offer_shown` → `hint_used`.
  Check `payment` as emitted; no ad is required for this path.
- **F2 rewarded:** `hint_stuck_offer_shown` → `ad_offer_shown`
  (verified rewarded hint placement) → `ad_reward_earned` (same placement)
  → `hint_used` (verified rewarded payment).

Use a closed funnel and indirect transitions. Never count
`ad_offer_shown` as a reward or award an item before provider
`ad_reward_earned`. Validate no-fill, early close, denied consent and
airplane-mode paths against the event stream: no false reward event.

## F3 — Store purchase

Closed funnel, indirect transitions:
`shop_opened` → `iap_purchase_started` → `iap_purchase_completed`.

Filter `product_id` consistently on start/completion for the canonical
test SKU, and verify `iap_purchase_completed` is emitted only after
a **durable grant**. Test cancellation/deferred/failed purchase separately:
none must count as completed. Use the store's sandbox/TestFlight/test
purchase process only. Do not make or claim a real purchase.

## Device execution plan — evidence is not yet collected

Reference devices: **Samsung Galaxy A15 (Android)** and **iPhone 13 Pro Max
(iOS)**. Repeat on other reference devices if release policy requires them.

1. Start from a fresh install or isolated disposable test state.
   Record the build SHA, device OS, local date and consent mode in the CSV.
2. Turn on provider DebugView, using the actual installed package name:
   Android: `adb shell setprop debug.firebase.analytics.app <PACKAGE_NAME>`;
   disable afterward with `adb shell setprop debug.firebase.analytics.app .none.`
   iOS: add `-FIRDebugEnabled` to the test scheme in Xcode; disable using
   `-FIRDebugDisabled`. Check the official provider instructions before use.
3. **Unknown consent:** trigger boot and events; verify only local queue
   exists and no Analytics SDK event/user property reaches DebugView.
4. **Allow:** confirm queued events are handed off in chronological order,
   have schema-correct parameters and required common context.
5. **Deny/revoke:** confirm queued events are dropped and no new event/user
   property goes to the provider. Repeat after relaunch.
6. **Offline:** with authorization and airplane mode enabled, play relevant
   steps; confirm local queue persistence. Reconnect and confirm delivery
   without inventing an exactly-once network guarantee.
7. **F1:** complete the required slots; verify exact values and steps
   1–8. On another local calendar day, inspect D1 via a separate cohort.
8. **F2:** exercise a direct hint, a rewarded hint, a no-fill and an
   early-close. Confirm the event sequence and absence of false rewards.
9. **F3:** use a sandbox purchase and a cancellation/deferred attempt.
   Confirm product IDs, one durable grant and no completion for cancellation.
10. Capture redacted DebugView and funnel-settings evidence links,
    with no personal identifiers. Record PASS/FAIL/BLOCKED against each
    case in `docs/qa/T-0258-device-evidence.csv`.

## Dashboard configuration and acceptance

- In GA4/Firebase select the **correct property and app stream**, then
  GA4 Explore → Funnel exploration. Name the three saved artifacts:
  `WOW F1 Onboarding`, `WOW F2 Hint` (with direct/rewarded variants),
  and `WOW F3 IAP`. Set closed/ordered steps, clear segmentation and the
  test date range. Do not publish claims based on DebugView alone.
- Verify numeric slot filtering before marking F1 configured. Verify
  provider console actually exposes all required event parameters.
- Check that developer/debug traffic is appropriately excluded from
  production KPI reports; DebugView and production funnel counts need
  not match in real time.
- Screenshot links/timestamps must be **from real devices and the real
  provider project**. No screenshots or PASS values are fabricated.
- Final acceptance: F1–F3 are **saved in the dashboard**, positive and
  negative QA scenarios pass on both operating systems, privacy modes
  behave as expected, and Chris signs off the completed evidence matrix.
- If any prerequisite or reporting limitation remains, keep T-0258
  `blocked` and publish an actionable blocker instead of marking done.

## Official provider references

- Firebase DebugView: https://firebase.google.com/docs/analytics/debugview
- GA4 Funnel explorations:
  https://support.google.com/analytics/answer/9327974
- GA4 numeric app parameters / custom dimensions:
  https://support.google.com/analytics/answer/14239696
