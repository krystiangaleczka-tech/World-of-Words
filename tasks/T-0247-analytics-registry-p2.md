---
id: T-0247
title: Complete typed core analytics registry for P2
epic: E17
type: contract
area: data.analytics
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0203, T-0033]
touch:
  - game/data/analytics/*.json
  - game/services/analytics/analytics_registry.gd
  - game/services/analytics/registry.schema.json
  - game/tests/integration/test_analytics_p2_registry.gd*
  - tools/tests/test_analytics_p2_registry.py
  - tools/tests/test_check_registries.py
  - docs/qa/T-0247-analytics-registry-p2.md
  - tasks/T-0247-analytics-registry-p2.md
revision: 2
---

## Goal
Execute the next ready roadmap contract: exact PRODUCT core-event catalog with typed payloads.
T-0242–T-0246 remain blocked on the remaining T-0330 atomic backend prerequisites.

## Current state
Main531cc67 has four lifecycle definitions, atomic registry append/copy/exact primitive payload
validation, matching JSON schema and deterministic Fake-only FIFO Analytics service. T-0203/T-0033
are done. PRODUCT core-events table lists47 names. Decision0009 selects Firebase Analytics.

## Specification
1. Preserve lifecycle names/params/descriptions exactly; add separate area files for the remaining
   PRODUCT names only: consent, onboarding, level, tools, economy, meta, daily, ads, iap, system.
   Every definition has exact typed event-specific params and an English description. QA records
   the parameter table/units/reasons. Include P3 daily catalog entries as inert future contracts.
2. invalid_word_submitted must include language:string, slot:int, letters:string (FR-ANL-04).
   Economy amounts flatten to coins/hint/reveal:int; no raw purchase tokens/transaction IDs, ad IDs,
   free-form exceptions or personal data in these event contracts. IAP price_micros:int and
   price_currency:string avoid custom-dimension reserved currency name; only provider error codes.
   Typed primitive validation remains exact; no coercion of bool/int/float/string, safe finite numbers.
3. Runtime/schema both enforce lower snake_case, max40chars, absolute end (including newline rejection), reserved prefixes firebase_/google_/ga_,
   and frozen provider reserved mobile events/params from Google's naming rules; also avoid PRODUCT's
   screen_view and automatic ad_impression. Parameter restrictions protect custom reporting names.
   Unknown/duplicate/reserved/malformed definition append is atomic and retained definitions isolated.
4. No SDK, queue/consent/common envelope/runtime listener/Events or tracking-call changes. Common
   install/version/language/bucket context belongs to T-0250. Registry availability is not consent
   to collect/send. T-0248 independent irreversible-name review remains a separate release gate.
5. Keep existing tests untouched except shipped event-count oracle4→47 in listed tools test; add
   independent PRODUCT-table coverage, provider naming parity, exact payload rejection, area loading/
   duplicates, copy isolation and no adapter activity. No analytics/config/pipeline validator changes
   outside the explicit analytics schema/runtime name guard.

## Tests
Every PRODUCT event exactly once and all payloads typed/accepted; missing/extra/wrong type rejected
without queueing. Invalid-word required context/letters; IAP fields omit sensitive receipts. Reserved
names/prefixes/lengths blocked in runtime and JSON schema, patterns match. Immutable lifecycle,
atomic batch append and independent definition/payload snapshots. Full make check/task/scope/fresh
exact-head reviewer/14CI before sequential squash merge. No network calls in tests.

## Rollback
Untracked new registry entries/guards only; preserve existing lifecycle and no history rename.
