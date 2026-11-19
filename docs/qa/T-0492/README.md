# Illustrated campaign preview

| Polish campaign slots | Illustration |
| --- | --- |
| 1–2052 | Riverside village |
| 2053–4039 | Flowering orchard |
| 4040–6026 | Forest lake |
| 6027–10000 | Foothills |

## Rebuild the QA APK

Use a disposable checkout of this task and the ranked Polish content archive from T-0491. Extract `content/pl` from the archive. Check its `manifest.json` against the SHA-256 in [the artwork catalog](art/catalog.json). Move the checkout's bundled `game/content/pl` aside and copy in the ranked `pl` directory. Copy the five files in `art/` to `game/assets/art/qa-campaign/`.

Build with `tools/android_debug_build.py`, using the pinned Godot 4.7.2 Android templates, SDK and JDK. The build produces a signed prototype APK and an equivalent `android-debug-content.zip` resource pack. Use a new data directory when running the smoke test from the checkout.

```sh
XDG_DATA_HOME="$(mktemp -d)" godot --headless \
  --main-pack /path/to/android-debug-content.zip \
  --script docs/qa/T-0492/verify.gd
```

The smoke test boots the packaged game, checks each transition, switches high contrast on and off, and solves the first puzzle using viewport touch events. `make check` covers the existing campaign and the scaffold fallback with the stock content.

## Runtime screenshots

- [Compact phone, orchard](screenshots/level_COMPACT_PL_default_2053.png)
- [Regular phone, riverside village](screenshots/level_REGULAR_PL_default_1.png)
- [Tablet, foothills](screenshots/level_TABLET_PL_default_6027.png)
- [Regular phone, high contrast](screenshots/level_REGULAR_PL_hc_1.png)

The screenshots use Polish and the native Godot runtime with the exported QA resource pack. The debug overlay may show test-only diagnostics.

## Artwork provenance

OpenAI ImageGen generated a portrait contact sheet on 2026-11-19 from a text brief based on the repository's Ceramic art direction. The brief called for four calm landscapes painted in matte gouache on warm paper, with space for the grid and wheel and no embedded lettering. It used no external artwork or image references. The original sheet's SHA-256 is `631156599ea2bf496655740f008ce4f8c057505223177d8c423f8086f9e72622`. The four quadrants were exported as 512×768 WebPs.

These are QA preview assets. Production postcard selection and the commercial-use decision remain with T-0308/T-0309 and Q14. Physical-device visual review remains pending.
