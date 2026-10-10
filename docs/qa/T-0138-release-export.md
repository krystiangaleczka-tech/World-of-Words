# T-0138 actual release resource inspection

FR-DEBUG-06 is checked on an actual unsigned Android Release resource ZIP produced
by Godot4.7.2 --export-pack. No release APK or production signature is created.

## How to run

After installing the pinned templates in Godot's data directory:

```sh
uv run python tools/check_release_export.py builds/android-release-content.zip \
  --export --godot godot --report builds/android-release-inspection.json
```

To inspect an existing export without rebuilding:

```sh
uv run python tools/check_release_export.py builds/android-release-content.zip \
  --report builds/android-release-inspection.json
```

CI uses the existing toolchain image. Actions overrides HOME, so the job points
XDG_DATA_HOME at /root/.local/share (installed templates) and XDG_CONFIG_HOME at
/root/.config (installed public SDK/JDK editor settings). No signing secrets,
production keys, custom SDK dependencies or engine/export settings are changed.
Download world-of-words-release-content from a successful CI run: it contains the
checked ZIP and JSON report, identifying the archive by SHA256 and sorted file list.
This resource ZIP is not an installable APK.

## Policy and limits

The inspector rejects dedicated developer roots features/debug, ui/gallery,
features/level/gallery.*, tests and addons/gut. It follows .remap targets and checks
exported class-cache script references. Compiled .gdc and hashed .godot/exported
resources must have an allowed source remap, preventing an orphan converted scene
from escaping the file-list policy. Godot ECFG metadata is checked for the custom
debug feature; absent/empty features are valid. ZIP CRC, duplicate/noncanonical
paths, required Boot/Level/PL content/audio metadata and remap completeness are
also checked. No source-only preset assertion substitutes for this artifact check.

Inert debug translation resources and .gutconfig.json are allowed: they contain
copy/configuration, not executable developer code or screens. Shared Boot/Nav/Save
APIs guarded by OS.has_feature("debug") remain part of normal runtime code. The
policy checks the normal pinned Godot exporter layout; it does not prove arbitrary
renamed code has no developer behavior or replace a production runtime test.

## Evidence

Actual preflight Android Release export: 184 entries; all 12 converted scenes have
allowed source remaps; no dedicated developer code/screens or custom debug feature.
Final local check and fresh review evidence are recorded below before merge.

No device runtime, production signing, T-0136 configuration, T-0051 human phase
exit or FUN GATE is claimed. Those remain separate human work.

Local final evidence: full make check passed (218 GUT tests / 8524 assertions,
199 pipeline tests, 142 tools tests including 39 new inspector regressions,
registries and all 65 PL campaign levels). Actual fresh release ZIP passed:
184 files, custom_features=[], SHA256
109dc8d3254a8baad8e2a62adb6ea75bdb2512b8e05f9fac81557bc80c25b299.

Fresh independent reviewer approved implementation SHA
3d0284948cae82f54bd57c3f5d654a2b6f098010 with no blockers. Independently passed
all 39 inspector tests and verified exact report/ZIP agreement, CRC, 75 compiled
resource remaps and 49 shipped cached script references. Merge is conditional
on all 12 CI jobs including actual release inspection and debug APK passing.
