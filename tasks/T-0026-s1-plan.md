---
id: T-0026
title: Plan S1 platform SDK spike
epic: E02
type: spike
area: platform.analytics
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0003]
touch:
  - docs/spikes/S1-plan.md
  - docs/decisions/0007-app-identifiers.md
  - tasks/T-0026-*.md
revision: 1
---

## Goal
Turn decision 0001's fixed S1 pass/fail criteria into an executable Android/iOS test plan, survey the
current Godot 4.7.2 plugin options, and freeze neutral production and throwaway spike identifiers
before either store receives an upload.

## Context
- `docs/decisions/0001-engine.md#s1-pass-criteria` — T-0026 may add test items but may not remove P1-P11.
- `docs/design-pass/02-technologia.md#3-decyzja` — ads/IAP must work on real Android and iPhone without
  writing a native ads/IAP plugin from scratch.
- `docs/design-pass/11-ryzyka-i-fazy.md#1-główne-ryzyka` — platform SDK instability is a high-impact risk.
- `docs/PRODUCT.md#compliance-and-store-requirements` — UMP before ads init, ATT, privacy manifests and
  store declarations must match the actual SDKs.
- Roadmap row: `tasks/ROADMAP.md` T-0026.

## Current state
- Godot is pinned to 4.7.2 by decision 0001, still conditional on S1/S2 and the T-0033 engine gate.
- Decision 0001 already fixes P1-P11 and F1-F4 and lists initial plugin candidates.
- No `docs/spikes/S1-plan.md` exists.
- No final production/spike application identifiers are recorded.

## Specification
### Behavior
1. Survey maintained candidates for AdMob + UMP/ATT, Play Billing, StoreKit 2, analytics/crash and
   iOS haptics against Godot 4.7.2, with dated source links and known risks.
2. Select a first-choice candidate and a bounded fallback for each S1 capability; do not install SDKs.
3. Define an ordered test matrix that preserves P1-P11 and tells T-0027/T-0028 exactly what evidence
   counts as pass/fail.
4. Distinguish engine-gate failures from provider/plugin failures exactly as decision 0001 does.
5. Record one permanent, neutral Android applicationId / iOS bundle ID shared across production
   platforms, plus a separate `.spike` identifier that must never be uploaded as the production app.
6. The production identifier must not contain the working title "World of Words".

### Edge cases
| Case | Expected |
|---|---|
| candidate is archived/deprecated | retain only as historical context, do not select it |
| plugin raises minimum OS | record the floor for T-0033/Q9 |
| analytics plugin fails | use HTTP analytics fallback; do not fail the engine solely for that |
| crash plugin fails | record provider failure; do not fail the engine solely for that |
| haptics needs small native glue | allowed by decision 0001; record it for T-0033 |
| ads or IAP needs a native plugin written/substantially rewritten from scratch | S1 failure |

## Out of scope
- Installing plugins, editing `game/`, export presets, manifests, plist files or secrets.
- Creating AdMob/Firebase/Sentry/store-console resources.
- Running S1 on devices; T-0027 and T-0028 own execution.

## Tests
Documentation review:
- every P1-P11 row appears in `docs/spikes/S1-plan.md` with pass evidence.
- every candidate recommendation has a dated public source.
- identifiers in `docs/decisions/0007-app-identifiers.md` are neutral and differ only by `.spike`
  for throwaway builds.

## Acceptance
- `tools/tasks.py lint` and repository CI pass.
- Only files in `touch` change.
- T-0027 can execute Android S1 without making an additional provider-selection decision.

## Escalation log
None.
