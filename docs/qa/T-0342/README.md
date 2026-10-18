# T-0342 — Settings Restore Purchases

Preflight: main fd686b5, merged T-0341 and Settings screen APIs verified. This is
ROADMAP T-0288's restore presentation split, using existing catalog controls only.
Same-Save binding is checked by the actual service; no provider/Save write occurs
on binding. Unbound screens keep their original action intent.

## Native evidence

36 real viewport PNGs from pinned Godot 4.7.2, X11/Compatibility llvmpipe: three
layouts x PL/PSEUDO x default100/HC130 x pending/completed/settling. manifest.json
contains exact dimensions/bytes/SHA256. Primary visually inspected the worst-case
COMPACT/PSEUDO/HC130 states; loading spinner has its own catalog leading slot,
Caption feedback wraps, status/count are readable, and settlement retry is visible
without a provider spinner. Complete/empty results require service proof.

Native suite passed 14/14 tests, 393 assertions, including 72 capture assertions.
Headless geometry runs the same behavior without claiming rendered output. Real
Save/Economy/Monetization and controlled store cover ownership, duplicates, busy,
failure/timeout, durable retry without another restore, reentry/hidden feedback,
service loss/rebind (including a retained owner leaving the tree while Settings
is detached), stale command error supersession, Back, keyboard, live copy/theme
and nested dispatch. Full local
check, independent review and exact-head CI evidence are recorded in the PR.

Reproduce with a native X11 DISPLAY, from repository root:

```sh
WOW_SETTINGS_RESTORE_CAPTURE_DIR="$PWD/docs/qa/T-0342" LIBGL_ALWAYS_SOFTWARE=1 \
  /path/to/Godot_v4.7.2-stable_linux.x86_64 --path game \
  --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy \
  -s addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/integration/test_settings_restore.gd -gexit
```

## Open gates

Global Settings boot/Nav activation and actual SDK/store restore certification
remain open, together with other T-0288 consent/privacy/browser/support actions.
Native desktop images do not certify a phone/store. No SDK, endpoint, permissions,
save schema, economy grant, products or analytics changes are introduced.
