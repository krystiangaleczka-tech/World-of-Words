# Home native screenshot matrix

Godot 4.7.2 ed1daf0bf on Apple M3, native macOS OpenGL/Metal compatibility renderer.
Official gallery dimensions: COMPACT 1080×1920, REGULAR 1080×2340, TABLET 1440×1920.
All captures use fake safe insets (24/48/24/48), a deterministic clock and memory-only SaveStorage.

The named location and geometric illustration are **QA fixtures only**. They are not production
locations, content packs or approved postcard artwork. Production legacy content currently shows
the missing-art state and remains playable. Journey/Daily/Collection are hidden until implemented;
Settings is disabled and currency presentation is passive. The existing Home mockup is in
[T-0205](../../design/T-0205/README.md); the authoritative screen spec is [Home](../../DESIGN.md#home).

| Layout | PL default100, fixture | PSEUDO HC130, fixture | PL default100, missing art | PSEUDO HC130, missing art |
|---|---|---|---|---|
| COMPACT | [image](COMPACT_PL_default100_fixture.png) | [image](COMPACT_PSEUDO_hc130_fixture.png) | [image](COMPACT_PL_default100_missing_art.png) | [image](COMPACT_PSEUDO_hc130_missing_art.png) |
| REGULAR | [image](REGULAR_PL_default100_fixture.png) | [image](REGULAR_PSEUDO_hc130_fixture.png) | [image](REGULAR_PL_default100_missing_art.png) | [image](REGULAR_PSEUDO_hc130_missing_art.png) |
| TABLET | [image](TABLET_PL_default100_fixture.png) | [image](TABLET_PSEUDO_hc130_fixture.png) | [image](TABLET_PL_default100_missing_art.png) | [image](TABLET_PSEUDO_hc130_missing_art.png) |

Reproduce with the pinned native engine from the repository root:

```sh
godot --path game --script "$PWD/docs/qa/T-0244/capture.gd" -- "$PWD/docs/qa/T-0244"
```

The external capture loads fixtures after autoload registration and renders isolated SubViewports;
it never loads or writes the user's real save. Physical device screenshots, visual taste and Polish
copy approval remain Chris's UI acceptance gates.
