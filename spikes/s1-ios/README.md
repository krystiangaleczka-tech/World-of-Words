# T-0028 iOS S1 diagnostic

This is a disposable Godot 4.7.2 project for the S1 iOS matrix. It is not production code and a
successful editor/import smoke check is not a P1-P11 pass.

## Pinned dependencies

- Poing AdMob 5.1.0 + `ios-template-v4.7.2.zip` (Google Mobile Ads iOS 13.9.0; min iOS 15).
- OpenIAP `godot-iap 3.6.2` (StoreKit 2; min iOS 17).
- Haptics first choice: `toniqat/godot-haptics` commit
  `75cf71c6b0ea0db6a7023009240391dadd2c3710`. It has no tagged binary release, so build/install it
  locally for Godot 4.7 before P8; do not treat `Input.vibrate_handheld` fallback as P8 evidence.

Run `sh ./setup.sh`, open this folder in Godot 4.7.2 and confirm both editor plugins are enabled.
Create an iOS export preset locally with bundle ID `com.mazen.worldofwordgame.spike`, deployment
target at least iOS 17 and the local signing team. Never commit signing/provider files.

## Device execution

Use iPhone 13 Pro Max and Xcode 26+ with the iOS 26 SDK. Follow `docs/spikes/S1-plan.md` in order:
P1 UMP/ATT allow+deny, P2 rewarded, P3 interstitial, P4 consumable with both kill points, P5 restore,
P6 analytics, P7 crash, P8 native haptics, P9 silent switch, P10 App Store Connect/TestFlight and
P11 the 10-minute stability loop.

Store screenshots/logs locally until scrubbed of secrets. Put only non-sensitive evidence under
`spikes/s1-ios/evidence/` and reference it from `docs/spikes/S1-ios.md`. Missing prerequisites are
DEFERRED / NOT EXECUTED, never PASS.
