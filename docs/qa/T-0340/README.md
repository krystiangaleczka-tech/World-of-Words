# T-0340 — licences screen native proof

Reference: DESIGN.md#settings and FR-SET-03. Existing catalog only: ScreenScaffold,
TopBar/IconButton, ListRow, ScrollContainer and theme Body/Subtitle labels. No new
component or generated theme change. This is the licences presentation portion of
T-0288; its external/native actions remain open.

## Native evidence

36 actual SubViewport PNGs captured through pinned Godot 4.7.2, X11/Compatibility
software rendering (llvmpipe), not headless rendering. manifest.json records exact
sizes, bytes and SHA256. Three layouts x PL/PSEUDO x default100/HC130, with index,
source-notice top and source-notice bottom in every case. The bottom includes the
last BSD disclaimer without clipping; long source URLs/hashes wrap horizontally.
Legal notices remain in their canonical language even in pseudolocalization.

Visually inspected COMPACT/PSEUDO/HC130 index and notice top, plus TABLET/PL/default
notice bottom. Short TopBar title remains visible; the long translated source
heading scrolls with detail. Keyboard focus moves to the scroll region on detail;
Back restores selected index-row focus. The actual settings-to-licences route is
exercised with caller-owned intent wiring, without a Save change.

Reproduce from repository root (with native X11 DISPLAY configured):

```sh
WOW_LICENCES_CAPTURE_DIR="$PWD/docs/qa/T-0340" LIBGL_ALWAYS_SOFTWARE=1 \
  /path/to/Godot_v4.7.2-stable_linux.x86_64 --path game \
  --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy \
  -s addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/integration/test_licences_screen.gd -gexit
```

Focused native suite: 6/6 tests, 419 assertions. Headless geometry suite excludes
image assertions (347 assertions). All seven notices are verified verbatim, with
invalid-selection, two-stage Back, keyboard, reentry and live translation/theme
checks. Full make check, independent review and exact-head CI evidence are in PR.

Physical Android/iOS readability and global Settings boot/Nav activation remain
open. No store/privacy/support action or native SDK certification is implied.
