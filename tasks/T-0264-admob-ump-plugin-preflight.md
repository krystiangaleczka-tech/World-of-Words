---
id: T-0264
title: Integrate pinned AdMob and UMP native plugins with platform declarations
epic: E18
type: infra
area: infra
risk: high
executor: cheap
think: high
ui: none
status: blocked
depends_on: [T-0259, T-0208]
touch:
  - docs/qa/T-0264-native-preflight.md
  - tasks/T-0264-admob-ump-plugin-preflight.md
revision: 1
---

## Goal
Make a reviewed, reproducible native AdMob/UMP bridge available on both platforms without showing ads or bypassing consent.

## Context
FR-ADS-06, FR-CONSENT-04, AGENTS.md S7/S11 and ROADMAP.md T-0264. Native manifest, plist, permissions and third-party SDK changes are high-risk.

## Current state
T-0263 exercises only Fakes. No owner-certified AdMob app IDs, pinned plugin API, platform exports or device logs exist on main. T-0226 iOS build loop remains an open PR at the time this planning record was written; T-0259 is not owner-approved.

## Specification
Blocked preflight, not permission to insert unverified SDK code. On a later revision:
1. Inspect the merged iOS build loop, accepted S1 plugin results and current Godot version. Select maintained version-pinned Android/iOS-compatible AdMob and UMP bindings with license and source evidence; document exposed methods/signals.
2. Specify exact files and separate Android manifest AD_ID / app ID declarations, iOS plist app ID / SKAdNetwork / ATT usage description and all permissions for owner approval under S7/S11. Use only real owner-provided IDs; permit test units for testing.
3. Test unsigned/signed Android export and iOS compile/device launch. Fake selection must make **zero** native SDK calls and no ads may initialize before consent.
4. Separate plugin integration from consent adapter T-0265 and ad presentation T-0266; do not change monetization or purchase semantics.

## Tests
`docs/qa/T-0264-native-preflight.md`: exact plugin version/API and licensing, S1 references, Android manifest/export logs, iOS plist/build logs and Fake smoke check. Mark checks `BLOCKED` until run on real tooling.

## Acceptance
Keep `blocked` until T-0259, T-0208 and roadmap's T-0226 are merged/verified, owner approves every manifest/plist/identifier change, and a new task revision names exact touch files and tests. Do not infer SDK support from documentation alone.

## Rollback
Disable the native provider selector before reverting pinned SDK binaries/configuration.

## Planning dependency gate
Add T-0226 to metadata when its currently unmerged task file reaches main.
