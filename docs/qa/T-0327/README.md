# T-0327 — native gallery CI evidence

The runner drives `GalleryShell.configure` and reads `preview_viewport()`; it does not reconstruct pages. Every currently registered page is captured in COMPACT1080x1920, REGULAR1080x2340 and TABLET1440x1920, PL/PSEUDO (gallery-owned EN basis, +35% accents), default100/HC130, reduced motion on and fake insets off. Fifteen pages produce 180 PNGs. New registered pages expand the matrix automatically.

Run from the checkout with the pinned Godot 4.7.2 binary:

```sh
uv run python tools/gallery_screenshots.py --godot godot --output builds/gallery
```

The output must be fresh/empty and under this checkout's `builds/`. With no DISPLAY the runner starts Xvfb; with an existing native DISPLAY it uses that server. Both paths request Compatibility/X11, software Mesa rendering and Dummy audio. Native artifacts include `version.log`, `import.log`, `render.log`, `manifest.json` and offline `index.html`. The manifest records actual engine/display/renderer/adapter, exact matrix, PNG byte counts and SHA256. It validates complete unique coverage, paths, PNG chunk framing/CRCs/dimensions and rejects engine errors even when Godot exits zero. Partial output/logs remain available after failure, and CI retains the failing result while uploading them.

The PR-only `Gallery screenshots` check renders changes under `game/ui`, `game/features` or `game/locale`, plus changes to the runner/tests/workflow. A verified Git merge-base diff with rename detection disabled includes deletes and moves out of UI; unrelated docs skip capture. Existing Release gallery exclusions cover the new capture script.

Local evidence: 30 focused Python tests pass, including real Git rename/deletion behavior and corrupt/incomplete output rejection. Native Godot 4.7.2 Compatibility/llvmpipe on Xorg dummy rendered the complete 180-image matrix; sample Controls/default100/PL was visually inspected. The initial X11 capitalization and API/CLI version-string differences were corrected; the successful render has no engine errors. Desktop evidence does not certify reference devices or establish a pixel-diff baseline.

Full `make check`, independent pack review and CI artifact verification are recorded in the PR. The 180 PNGs remain in the downloadable CI artifact rather than repository history. Download/unzip the artifact and open `index.html` locally; manifest hashes allow verification of each PNG.
