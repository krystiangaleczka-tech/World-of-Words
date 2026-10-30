---
id: T-0266
title: Deliver callback-safe AdMob rewarded and interstitial adapters
epic: E18
type: feat
area: platform.ads
risk: high
executor: cheap
think: high
ui: low
status: blocked
depends_on: [T-0265]
touch:
  - docs/qa/T-0266-ads-preflight.md
  - tasks/T-0266-admob-ads-adapter.md
revision: 1
---

## Goal
Map pinned native AdMob rewarded/interstitial events into the already-tested adapter envelope, without duplicating grants or showing forced ads to owners.

## Context
FR-ADS-03..08; GAME_DESIGN.md#ad-policy; ROADMAP.md T-0266. The real SDK must not choose policy or write wallet state.

## Current state
T-0263 implements Fake ad flow; T-0264/T-0265 native transport and consent are not certified. No current plugin callback signatures or device test logs exist.

## Specification
Before ready, inspect the exact merged plugin/native API and frozen `AdsAdapter` signal names; update task with exact source/test touch paths.
1. Use provider official **test ad units** on each platform. Match load, ready, present, earned, closed, no-fill, timeout and error callbacks to the frozen adapter.
2. An earned reward is delivered at most once to Monetization; close/failure alone never grants. Adapter itself neither creates coins nor modifies Save.
3. Preserve no forced ads when `nc.remove_forced_ads.v1` is owned; service alone decides when an interstitial can show. No show on daily, app start or during a level.
4. Correctly pause/resume audio while presenting; background/foreground and duplicate or delayed callbacks never make a stuck operation.
5. No external network/ad requests before required UMP/ATT resolution; Fake mode remains SDK-free.
6. If native integration fails twice, escalate for the agreed Opus runtime review; do not invent bindings.

## Tests
`docs/qa/T-0266-ads-preflight.md`: callback-to-adapter matrix for load/show/earn/early close/no-fill/offline/background, duplicate callbacks, consent barriers and owned entitlement; attach redacted native logs. Add deterministic adapter tests to the executable revision once APIs are known.

## Acceptance
Keep `blocked` pending proven native plugins/consent, verified callback map and Android/iOS smoke tests. No production ad IDs or ad requests yet.

## Rollback
Disable real adapter selection, leaving Fake behavior and durable entitlements unchanged.
