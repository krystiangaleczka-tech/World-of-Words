---
id: T-0344
title: Own serialized privacy options operation and explicit result
epic: E21
type: contract
area: services.monetization
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0343, T-0341]
touch:
  - game/services/monetization.gd
  - game/platform/consent/consent_adapter.gd
  - game/platform/consent/consent_fake.gd
  - game/tests/integration/test_privacy_operation.gd*
  - docs/contracts/monetization.md
  - tasks/epics/E21-settings.md
  - tasks/T-0344-privacy-operation.md
revision: 1
---

## Goal
Implement the service portion of ROADMAP T-0288 Privacy Options as a bounded
Phase-2 rolling-wave split, consuming T-0343 evidence before future Settings UI.
Acceptance, changed consent and completed form are distinct observations.

## Context
- docs/PRODUCT.md#fr-consent-privacy-consent: FR-CONSENT-03 requires reopening
  privacy options when required; FR-CONSENT-02 requires purpose-specific analytics.
- docs/contracts/monetization.md#independent-privacy-options-requirement-t-0343:
  UNKNOWN does not authorize visibility/opening. Provider requirement is independent.
- Existing adapters must correlate operations and suppress obsolete callbacks.

## Current state
Verified on main 808b24a: Monetization.configure, start_session, before_next_level,
expire_operation, _on_consent/_on_analytics, same-Save restore ownership and IAP
commands exist. Step INFO/FORM/ATT/INITIALIZING and one-shot ALWAYS/ignore-time-scale
120-second legal timer exist. ConsentAdapter exposes requirement getter/change,
show_privacy_options, consent_resolved and operation_failed, but no dedicated
privacy terminal result. ConsentFake has generation-controlled outcomes/tokens.
No service privacy command/snapshot/owner check or UI binding exists.

## Specification
- Add optional ConsentAdapter.privacy_options_completed(error:Error): authoritative
  terminal result for the current show_privacy_options operation only. OK means
  form operation completed, never consent granted. Native providers must suppress
  duplicates/obsolete results. Legacy adapters without this signal time out.
- Fake keeps existing consent_resolved/operation_failed compatibility, then emits
  this dedicated terminal only for its still-current show_privacy_options token:
  valid known UMP outcomes -> OK, unknown -> ERR_INVALID_DATA, error -> FAILED.
  A reentrant superseding command/reset during legacy notification prevents terminal.
- Monetization.privacy_snapshot()->Dictionary returns fresh requirement:StringName
  (unknown/not_required/required), available:bool, state:StringName, error:Error,
  revision:int. available means live configured loaded owner + required evidence,
  independent of operation busy. States idle/requested/completed/failed/unknown;
  unconfigured/detached/lost binding reads unavailable and UNKNOWN/false.
- privacy_changed notifies provider requirement and operation transitions with
  increasing instance revision. configure resets operation and reads current provider
  evidence without calls; disconnect old adapter listeners. Retained service exit
  invalidates privacy binding until explicit valid reconfigure.
- privacy_owner_matches(save:Node)->bool certifies exact actual loaded Save and live
  connected configured service, independent of IAP binding.
- request_privacy_options()->Error: only REQUIRED may dispatch; UNKNOWN/NOT_REQUIRED
  return ERR_UNAVAILABLE, missing live binding ERR_UNCONFIGURED. Reject while legal/
  Continue, ads presentation/earned settlement, IAP query/purchase/restore/settlement,
  privacy notification or dispatch is active. Rejected calls never replace result.
- Acceptance sets requested/OK, disables ad readiness, enables existing explicit
  analytics relay and uses existing legal timer. Notify before provider dispatch;
  expiry from that notification suppresses obsolete dispatch. No boot refresh,
  ATT, ad initialize/load/show, IAP or Continue is implicitly triggered.
- Only dedicated terminal ends requested: completed/OK or failed/actual error.
  Generic consent updates may update UMP evidence but cannot complete/open another
  form or initialize ads. Generic operation_failed alone cannot certify a privacy
  terminal. First terminal wins. Requirement changes do not settle pending work.
- expire_privacy_options()->void and existing expire_operation watchdog finish
  requested as unknown/ERR_TIMEOUT, stop timer/analytics relay; late results ignored.
  Explicit retry if still required starts a new request; adapter suppresses old tokens.
- Privacy pending/notification/dispatch blocks configure, configure_iap, start_session,
  before_next_level, purchase, restore_purchases, process_unfinished_transactions,
  request_products, request_rewarded, request_shop_reward and restore settlement retry
  with ERR_BUSY. This protects callback reentry through completion as well.
- Explicit analytics_resolved decisions alone relay Events.consent_changed, including
  a privacy operation before start_session; no implicit grant/revocation. Error or
  expiry stops relay; success permits the provider's purpose decision after closing.
  No new event/schema. Existing nonprivacy command/consent/settlement policies stay.

## Tests
New test_privacy_operation.gd: defaults/owner/read copies; explicit requirement
transitions; accepted once vs terminal; sync success/error/unknown; consent-only and
legacy failure are not terminal; expiry/late/explicit retry; requirement change while
pending; purpose-specific analytics independence; serialization both directions
(legal/Continue, ad presentation/earned retry, IAP query/purchase/restore/settlement);
reentrant requested/terminal/dispatch commands and reconfigure; no obsolete Fake
terminal after supersession; disconnect/reconfigure/retained exit; timer settings
without real-time sleeps. Existing suites unchanged and green.

## Acceptance
Full make check, fresh independent review, exact-head CI including Android green.

## Out of scope
Settings UI/boot/Nav binding, native SDK/provider implementation/certification,
endpoints/permissions, persisted consent/save schema, economy rules or new analytics.

## Rollback
Squash revert removes additive unactivated APIs; no persistent data migration.
