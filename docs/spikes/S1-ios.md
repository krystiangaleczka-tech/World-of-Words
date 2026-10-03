# S1 iOS execution report — T-0028

Date: 2026-10-04. **Task: DONE by Chris scope acceptance; device/store matrix: DEFERRED / NOT EXECUTED.**

The repository-side diagnostic harness is prepared on `t/0028-s1-ios`. This execution path has no
access to Chris's iPhone, Xcode signing identity, App Store Connect, AdMob/UMP, analytics or crash
provider resources. No P1-P11 row is promoted from a static/plugin preflight to PASS.

## Environment and pins

- Engine target: Godot 4.7.2 standard build.
- Reference device: iPhone 13 Pro Max.
- Disposable bundle ID: `com.mazen.worldofwordgame.spike`.
- Poing AdMob 5.1.0; iOS template for Godot 4.7.2, native GMA SDK 13.9.0.
- OpenIAP godot-iap 3.6.2; StoreKit 2, OpenIAP Apple 3.6.1, minimum iOS 17.
- Native haptics candidate: `toniqat/godot-haptics` commit `75cf71c...`; no tagged binary release.
- `spikes/s1-ios/setup.sh` pins public archives by SHA-256 and writes no secrets.

## Repository preparation

- T-0027 dependency is merged through PR #9.
- The harness reports AdMob native singleton presence, OpenIAP `GodotIap` class/autoload presence
  and Haptics singleton presence without making ad, consent or purchase calls.
- Ads and IAP intentionally remain inactive until real UMP/ATT and sandbox resources exist.
- iOS signing/export preset and provider configuration stay local and uncommitted.

## P1-P11 results

| ID | Result | Evidence still required |
|---|---|---|
| P1 Consent | NOT EXECUTED | UMP at slot 1; ATT only after slot 6; allow/deny clean installs; init ordering |
| P2 Rewarded | NOT EXECUTED | test unit; reward exactly once; early close zero |
| P3 Interstitial | NOT EXECUTED | load/show/close and exact state restoration |
| P4 Consumable | NOT EXECUTED | StoreKit 2 transaction ID, durable grant, explicit finish, both kill points |
| P5 Restore | NOT EXECUTED | sandbox purchase, reinstall, restore/current entitlement |
| P6 Analytics | NOT EXECUTED | denied default, queue send/drop and dashboard event |
| P7 Crash | NOT EXECUTED | dashboard crash with version tags and readable GDScript stack |
| P8 Haptics | NOT EXECUTED | native selection/impact felt when enabled and absent when disabled |
| P9 Silent switch | NOT EXECUTED | SFX audible with switch off and silent with switch on |
| P10 Store upload | NOT EXECUTED | Xcode 26+/iOS 26 archive accepted and installed from TestFlight |
| P11 Stability | NOT EXECUTED | 10-minute ads + purchase/query/restore loop with no loss/crash/hang |

## Blocking prerequisites

1. Run the project on Chris's Mac with Godot 4.7.2, Xcode 26+ and the iPhone 13 Pro Max.
2. Prepare the `.spike` App Store sandbox app/products/test account and published AdMob/UMP setup.
3. Prepare non-production analytics/crash resources and install/build the native haptics plugin.
4. Execute P1-P11 and replace only rows backed by real evidence with PASS/FAIL.

No F1/F2/F3 determination can be made from the repository preflight. Task completion does not mean
the S1 iOS matrix passed; T-0033 must preserve that distinction.

## Completion decision — 2026-10-04

Chris explicitly accepts the repository-side diagnostic preparation as the current completion scope
for T-0028 and marks the task done. All P1-P11 device/store rows remain DEFERRED / NOT EXECUTED and
require follow-up validation before release. The accepted risk is later discovery of iOS SDK/store
integration problems and possible rework; no change to decision 0001's S1 pass criteria is implied.
