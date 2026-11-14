---
id: T-0259
title: Configure AdMob publisher account, UMP messages and app-ads.txt domain
epic: E18
type: docs
area: store
risk: high
executor: human
think: none
ui: none
status: blocked
depends_on: []
touch:
  - docs/store/T-0259-admob-setup.md
  - tasks/T-0259-admob-account-and-privacy-setup.md
revision: 1
---

## Goal
Owner configures verified advertising identities, consent messages and an authorized publisher domain before native SDK work. No account or live ad inventory is invented by an agent.

## Context
- PRODUCT.md#compliance-and-store-requirements: `app-ads.txt` belongs at the root of the store-listed developer domain.
- FR-CONSENT-01; FR-ADS-06: no ad SDK initialization before UMP resolves.
- ROADMAP.md T-0259; AGENTS.md S11 applies to credentials, network domains and app identifiers.

## Current state
T-0263 is Fake-backed; no real AdMob account, production app IDs, test unit IDs, approved consent message, or ownership verification is recorded on main. Roadmap prerequisite T-0012 (store accounts) and T-0143 (FUN GATE) have no task files in current main; verify their actual owner decisions first. Privacy policy work is T-0313 and must use the same developer domain.

## Specification
1. Chris signs into the actual AdMob account, verifies publisher ownership and registers both platform apps with the final package/bundle identifiers. Record non-secret app IDs and ad-unit mapping (rewarded, interstitial) separately for Android and iOS; distinguish test IDs from production IDs.
2. Configure the required EEA/UK UMP privacy message and privacy-options entry. Verify live console status; record relevant regional settings and consent-mode behavior without copying user data.
3. Select a developer website domain also suitable for T-0313 privacy policy, authorize it in store metadata and publish AdMob-provided `app-ads.txt` at the **domain root**. A GitHub Pages project subdirectory does not qualify.
4. Verify `https://<approved-domain>/app-ads.txt` via HTTPS/HTTP response and exact publisher line against the actual AdMob UI, with date and non-secret evidence. Record privacy-policy URL alignment.
5. No guessed IDs, unpublished publisher IDs, credentials, store-console claims or production ad activation. No SDK edits in this task.

## Tests
`docs/store/T-0259-admob-setup.md`: account ownership, platform registration, unit inventory, UMP message and privacy form configuration, selected domain, public app-ads.txt HTTP check, store metadata and privacy policy consistency. Record **PASS/FAIL/BLOCKED** and owner/date/evidence link for each check. Never copy access tokens or personal account details.

## Acceptance
Owner confirms each console and public-domain check with evidence, then changes this task to `review`. If any prerequisite is missing, leave `blocked`; no store setup is claimed.

## Rollback
Do not delete/recreate irreversible advertising accounts or public app IDs without an explicit owner decision. Unpublish only test placements if necessary.

## Planning dependency gate
ROADMAP.md requires T-0012 and T-0143. Neither is materialized on current main; add both to `depends_on` when files exist, verify `done`, and release an executable revision only then.
