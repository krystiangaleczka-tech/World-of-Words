# Floating islands in the ranked Polish campaign

| Slots | Island | Views |
| --- | --- | --- |
| 1–2052 | Rzeczna Dolina | Riverside village, watermill, stone bridge |
| 2053–4039 | Kwitnący Sad | Orchard path, blossom lane, spring stream |
| 4040–6026 | Leśne Jezioro | Timber jetty, birch cove, wooded headland |
| 6027–10000 | Złote Pogórze | Foothills, trail refuge, mountain meadow |

The preview opens on the map for both new and returning players. Home reads the saved slot and identifies the current island. Play resumes that slot. Each island starts its own three-view sequence which repeats by slot. Returning to a given slot shows the same view.

## Build and verify

Follow the ranked content staging instructions in [T-0492](../T-0492/README.md#rebuild-the-qa-apk). In the disposable checkout, copy this task's `art/` files into the same `game/assets/art/qa-campaign/` directory alongside the T-0492 art files. Run `tools/android_debug_build.py` with the pinned SDK, JDK and Godot templates. The catalog is selected in debug builds when its hash matches the loaded ranked manifest and all map resources are available.

From the code checkout, run the following with the resulting Android debug resource ZIP. The second run uses the same profile and verifies the freshly saved Level 2.

```sh
export XDG_DATA_HOME="$(mktemp -d)"
godot --headless --main-pack /path/to/android-debug-content.zip --script docs/qa/T-0493/verify.gd
godot --headless --main-pack /path/to/android-debug-content.zip --script docs/qa/T-0493/verify.gd -- resume
```

## Runtime screenshots

- [Map on a compact phone layout](screenshots/islands_COMPACT_PL_new.png)
- [Map on a regular phone layout](screenshots/islands_REGULAR_PL_new.png)
- [Map on a tablet layout](screenshots/islands_TABLET_PL_new.png)
- [Rzeczna Dolina at Level 1](screenshots/level_REGULAR_PL_river_1.png) and [Level 2](screenshots/level_REGULAR_PL_river_2.png)

The captures use the native Godot QA session and the staged ranked campaign.

## Artwork provenance

The four map markers and eight additional views were generated from original OpenAI ImageGen text prompts on 2026-11-20. The prompts used the repo's Ceramic direction, Polish countryside habitats, and matte gouache on warm paper. The marker sheet was split into four 768×512 WebPs with the low-opacity haze removed from the transparent margins. The two portrait sheets were split into eight 512×768 WebPs. The first view of each island uses the T-0492 illustration.

| Source sheet | SHA-256 |
| --- | --- |
| Floating island markers | `4f54213499ef7f9ff623af37a0d1f0ccb151be9c540c011864bb1098b87443eb` |
| Second view | `0c2cb935707ffeea105143a5e26f397f83272274ed5d0118894b0a2b531c6e15` |
| Third view | `53dbbb33174547416c354e1e3d908fbe42be1f0bda971d70aae0a034d18d4443` |

The illustrations are for QA. Production asset selection and physical-device review remain pending.
