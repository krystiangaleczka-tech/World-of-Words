# T-0335 — serial editor resource imports

## Failure and mechanism

The pinned engine is Godot4.7.2 ed1daf0bf001b61586d9930840f2f1394092c079.
The previous policy left resource imports parallel, the engine's default.
Actual cold-cache CI failures before GUT include:

- [PR199 theme import](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38977470914/job/117230264747): native `double free or corruption (out)` after import.
- [PR200 game import](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38979314282/job/117236173788): CSV reimport, fatal cowdata indices -1/15 and1/0, `/root` notification attempted from a non-caller thread, signal4. The same head passed after a targeted rerun.

Engine sources at the exact pinned revision:

- [ProjectSettings canonical key/default](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/doc/classes/ProjectSettings.xml#L1135): `editor/import/use_multiple_threads` is a boolean, default true.
- [CSV importer thread support](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/editor/import/resource_importer_csv_translation.h#L53): advertises `can_import_threaded() = true`.
- [Importer dispatch](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/editor/file_system/editor_file_system.cpp#L3333): reads that ProjectSettings key and uses WorkerThreadPool only when enabled; false dispatches individual imports on the calling main thread.

The worker/root-notification failure demonstrates an unsafe threaded import path.
The repository fix excludes that path with the supported engine setting; it does
not patch Godot C++ or claim a complete upstream memory-safety diagnosis for every
heap-corruption signature. Job reruns alone never removed this path.

## Change and coverage

`game/project.godot` now explicitly sets `[editor] import/use_multiple_threads=false`.
Make import, clean-cache theme generation, toolchain smoke and Android editor
exports all read this project file; the theme checker copies it into its shadow.
No runtime scene-thread setting, engine pin, autoload, export option or asset changed.
All error/warning checks remain strict. No retry, filtered diagnostic or cache reuse
was added. Tradeoff: cold editor imports may take longer; gameplay threading is
unchanged. The actual-Godot integration test rejects an absent, mistyped or enabled
canonical policy rather than assuming the default is safe.

## Reproduction

From repository root with new game test staged so the experiment includes it:

```
uv run python docs/qa/T-0335/stress.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --report docs/qa/T-0335/cold-import-report.json
```

Each attempt makes a new temporary project from Git-tracked game files only.
There is no `.godot`, inherited generated translation or untracked-cache input.
Only the disposable baseline copy changes the policy back to true. It runs up to
ten baseline imports, stopping at the first failure, then requires ten independent
serial imports. A nonzero exit, any ERROR/SCRIPT ERROR/WARNING, timeout, absent
translations or changed successful translation hashes fails the serial experiment.
Every attempt executes exactly once; raw logs remain in `/tmp/wow-t0335-imports`.
The checked-in JSON records engine, copied-source hash, durations, exit statuses,
diagnostics and all imported translation hashes. The working cache is not removed.

Local baseline reproduction is probabilistic and may pass on this machine. The
report records that outcome rather than pretending a failure was reproduced;
actual CI failure receipts above remain the evidence of the original problem.

## Recorded result

| Mode | Clean / attempts | Mean seconds | Maximum seconds |
| --- | --- | --- | --- |
| parallel | 10 / 10 | 6.952 | 8.62 |
| serial | 10 / 10 | 7.318 | 8.502 |

All20 imported locale output hashes match across successful baseline and
serial runs; all attempts used one identical copied-source snapshot before the
mode override. The new test's generated UID was added afterward; no runtime code
changed. Baseline did not reproduce locally (0/10 failures); this limits any local
causal claim. The exact engine dispatch branch and CI worker-thread failure remain
the basis for choosing the serial policy. Timings are observations, not a controlled
performance benchmark. No failed serial attempt was retried.

Full pinned make check PASS:795/795 GUT tests,27,776 assertions;329 pipeline
and536 tools tests; locale/token/registry/content and14 generated theme/font/CSS
outputs all green. No existing test modified.
