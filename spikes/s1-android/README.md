# S1 Android diagnostic project

This is the T-0027 device probe accepted as done by Chris, with full SDK validation deferred.
Use Godot **4.7.2 standard** with matching Android export/build templates, Android SDK 36
and Java 17. The package is always `com.mazen.worldofwordgame.spike`.

```sh
sh spikes/s1-android/setup.sh
godot --headless --path spikes/s1-android --import --quit
godot --headless --path spikes/s1-android --install-android-build-template --export-debug Android export/s1.apk
adb -s DEVICE install -r spikes/s1-android/export/s1.apk
adb -s DEVICE shell am start -n com.mazen.worldofwordgame.spike/com.godot.game.GodotAppLauncher
```

Configure Godot editor Android SDK / Java SDK paths before export. Upstream addons retain their
licenses locally and are excluded from Git together with build outputs. setup.sh verifies archive
SHA-256. AdMob uses Google's sample application ID; there is no real AdMob/UMP configuration.
The app lists native SDK singletons and connects to Billing; it never starts an ad request,
initializes MobileAds, purchases a product, emits analytics or crashes deliberately.
Its diagnostic strings are developer evidence, not production player-facing UI.

## Required for deferred full validation before release

- Play Console `.spike` app/internal track, dedicated signing, license tester and active products
  `c.coins_s.v1` (consumable) and `nc.remove_forced_ads.v1` (non-consumable).
- AdMob `.spike` Android app and published UMP message; replace the sample application ID locally
  and use the plan's test ad units/debug geography on the reference device.
- Firebase `.spike` app config and Sentry test-project DSN, kept out of Git. Pin their plugin
  releases before implementing P6/P7; absence of resources is not evidence of provider failure.
- Integrate consent, ads callbacks, durable purchase ledger with both interruption points,
  analytics consent queue and tagged readable GDScript crash stack in a follow-up execution round
  of this task. Install haptics first choice and obtain Chris's tactile observation for P8.
- Execute every Android row of `docs/spikes/S1-plan.md`; capture dashboard/store/device evidence.
  P10 needs the actual internal track; sideload is insufficient. P11 needs a real 10-minute
  ads/purchases/restore loop, not an idle diagnostic app.

Do not store service-account keys, signing passwords, purchase tokens or provider configs in Git.
See `docs/spikes/S1-android.md` for results and remaining prerequisites.
