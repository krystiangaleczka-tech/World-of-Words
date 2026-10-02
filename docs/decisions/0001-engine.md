# 0001 — Engine: Godot 4.7, conditional on spike S1

- Status: proposed (T-0003, 2026-10-02). The engine gate (T-0033, Sol + Chris) accepts it or replaces it
  with a superseding decision, after S1 Android (T-0027), S1 iOS (T-0028) and S2 swipe (T-0029).
- Context: design pass `02-technologia.md` §1–§3 (Godot vs Unity vs Kotlin Multiplatform), risks R1 and
  R15 (`11-ryzyka-i-fazy.md` §1), decision 0006 (Sol has no runtime; CI is its test loop).

## Decision
1. **Engine: Godot 4.7, standard build (no .NET).** The exact patch is the latest stable 4.7.y when T-0013
   merges: 4.7.2 (released 2026-08-18) on 2026-10-02. Godot 4.8 is still in dev snapshots and is not
   used.
2. **One build everywhere.** The editor, the headless binary in the Docker image (T-0014), CI (T-0018)
   and the Android/iOS export templates are the same 4.7.y build. `game/project.godot` (T-0013) is
   created with it.
3. **Language: typed GDScript**, untyped declarations are errors. No C#: it gives up most of Godot's
   advantages here (design pass 02 §3).
4. **Conditional.** Production code (E03 onward) starts only after T-0033 accepts this decision.
   Phase 0 tooling (T-0013 … T-0025) uses Godot before the gate; it is cheap to redo.
5. **Upgrades.** A patch upgrade (4.7.y → 4.7.z) is an `infra` task in lane `H`. A minor upgrade
   (4.8 or later) needs a new decision that supersedes this one.

## Why Godot
- The workflow is many small PRs by AI agents. Godot's project files are text with readable diffs, the
  repo stays small, and headless CI on Linux is free and fast. Unity scenes and prefabs are YAML with
  GUIDs that agents do not edit reliably, and its CI needs licence activation (design pass 02 §1–§2).
- Tweens, particles and 2D shaders give enough game feel for a 2D word game.
- Weakness 1, platform plugins (ads, IAP, analytics and crash reporting, mostly on iOS), is what S1
  tests. Weakness 2, models mixing up Godot 3 and 4, is handled by typed GDScript, warnings as errors,
  the pitfalls table in `AGENTS.md` and the headless import in CI.

## S1 pass criteria
Fixed before S1 starts. T-0026 turns them into the test matrix; it may add items, never remove one.
Runs use the reference low-end Android (Q13) and an iPhone, builds exported by the pinned version,
AdMob test units, the Play internal track and the StoreKit sandbox. Each item is recorded as pass or
fail in `docs/spikes/S1-android.md` and `docs/spikes/S1-ios.md`.

| # | Item | Pass when (both platforms unless noted) |
|---|---|---|
| P1 | Consent | The UMP form shows where UMP says it is required, and its outcome is readable from GDScript. The ads SDK initializes only after UMP resolves. iOS: UMP's IDFA explainer, then the ATT prompt (FR-CONSENT-04). |
| P2 | Rewarded ad | Loads, shows, and grants only in the "reward earned" callback. Closing early grants nothing (FR-ADS-04). |
| P3 | Interstitial ad | Loads, shows and closes; the game resumes in the same state. |
| P4 | Consumable purchase | Purchase, then grant, then consume (Android) or finish (iOS). The transaction key (`purchaseToken`, StoreKit 2 `Transaction.id`) is readable from GDScript (FR-IAP-03). |
| P5 | Non-consumable purchase and restore | Purchase, reinstall the app, restore: the entitlement comes back. No purchase is ever lost. |
| P6 | Analytics | One test event is visible in the provider dashboard. |
| P7 | Crash reporting | One forced crash is visible in the provider dashboard with a readable stack. |
| P8 | Haptics | A light tick is felt on both devices and can be switched off (iOS: native impact feedback). |
| P9 | Silent switch (iOS) | Sound effects respect the silent switch (FR-AUDIO-04). |
| P10 | Store upload | The Play Console internal track accepts the AAB without target-API or 16 KB page-size errors (API 36 has been required since 2026-08-31). App Store Connect accepts the build and it installs from TestFlight. |
| P11 | Stability | A 10-minute run that cycles ads and purchases ends with no crash, ANR or hang. |

## Failure criteria
Design pass 02 §3: if any ad or IAP integration needs a native plugin written from scratch, or does
not work stably, the engine decision is reopened. In detail:
- **F1 No usable plugin.** One of P1–P5 cannot pass with an existing, maintained plugin that supports the
  pinned version. A fork with small fixes is acceptable. Writing or substantially rewriting a native
  plugin is a failure.
- **F2 Unstable.** A crash, hang or lost purchase in P1–P5 reproduces with the plugin's documented setup.
  A lost purchase is always a failure.
- **F3 Store rejection.** The P10 build is rejected for an engine-level reason that export settings
  cannot fix.
- **F4 Swipe lag.** After the S2 recommended input approach, Chris judges the swipe latency perceivable
  on the reference low-end Android (NFR-01), and the cause is the engine, not the prototype code.

These are not failures; they are recorded for T-0033:
- An analytics or crash plugin does not work. Use an HTTP-based provider behind the same adapter
  (design pass 02 §3); answers Q8.
- Haptics or the silent switch need a small native plugin.
- Mobile screen readers (TalkBack, VoiceOver) are not supported on 4.7. Accessibility-label exposure
  moves to Later (FR-A11Y-04).

## Gate outcomes (T-0033)
- **All of P1–P11 pass:** this decision becomes `accepted` with the pinned version. T-0033 also records Q8,
  Q9, the haptics and silent-switch approach and FR-A11Y-04 in decision `NNNN-platform-providers`.
- **One failure with a credible fix in sight** (a plugin release, a 4.7 patch): Chris chooses between one
  more S1 round on a new task and the switch.
- **Otherwise:** a new decision supersedes this one with plan B, and T-0033 re-plans the Godot-specific E01
  rows (T-0013, T-0014, T-0015, T-0018), E03 and E04.

## Plan B: Unity 6.3 LTS
- Unity 6.3 is the current LTS, supported until December 2027 (6.0 LTS support ends October 2026).
  Licence terms are re-checked at the switch.
- Survives the switch:
  - the Python pipeline, JSON packs and schemas (`pipeline/`);
  - all docs and decisions, the task workflow, and the config and analytics registries;
  - design tokens (values);
  - the rules in `core/`, which are pure classes that port 1:1 to C#.
- Redone:
  - everything in `game/`;
  - the Godot parts of the Docker image and CI;
  - the GUT tests (moving to the Unity Test Framework);
  - the Godot sections of `AGENTS.md`.
- Known costs: agents cannot reliably edit scenes and prefabs, so UI would be built in code or UI
  Toolkit (text UXML/USS). CI needs licence activation, and iteration is slower (design pass 02 §2).

## Plugin landscape on 2026-10-02
These are input for T-0026, not a choice.
- **Ads, UMP and ATT:**
  - `godot-sdk-integrations/godot-admob`: Android and iOS, UMP built in, ATT signals, mediation.
  - `poingstudios/godot-admob-plugin`: Godot 4.5+, UMP, mediation.
- **Play Billing:** `godot-sdk-integrations/godot-google-play-billing`.
- **StoreKit 2:**
  - `godot-sdk-integrations/godot-storekit2` (v0.2 from 2025-09; its README says the API is not stable yet);
  - the StoreKit 2 support in `godot-sdk-integrations/godot-ios-plugins`;
  - `hyochan/godot-iap` (cross-platform).

  This is the weakest link and the most likely failure point.
- **Who maintains them:** `godot-sdk-integrations` is a community organization hosted by the Godot
  Foundation. The Foundation gives no endorsement or support for these plugins.
- **Android target API:** Godot 4.7 targets API 36 by default. Verify it in the exported AAB's manifest.

## Consequences
- T-0013 and T-0014 pin 4.7.y. T-0026 surveys the plugins against that exact version.
- Every platform service sits behind an adapter with a Fake (FR-PLAT-01), so a bad plugin costs one
  adapter, not the game.
- Rules live in pure `RefCounted` classes in `core/`, which keeps plan B affordable.
- Min Android API and iOS versions (Q9, NFR-09) follow from the chosen plugins and are decided at the gate.

## Revisit if
- S1 or S2 hits a failure criterion.
- A plugin the game depends on is abandoned with no fork that supports the pinned version.
- A store requirement (target API, SDK version) cannot be met on 4.7 and needs a minor upgrade.
