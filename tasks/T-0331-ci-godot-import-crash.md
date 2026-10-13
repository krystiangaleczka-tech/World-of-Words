---
id: T-0331
title: Diagnose the intermittent Godot CSV reimport crash and pin the CI toolchain image
epic: E09
type: infra
area: ci
risk: medium
executor: sol
think: high
ui: none
status: draft
depends_on: [T-0138]
touch:
 - .github/workflows/ci.yml
 - .github/workflows/toolchain-image.yml
 - tools/android_debug_build.py
 - tools/check_release_export.py
 - tools/tests/test_release_export.py
 - tools/tests/test_android_debug_build.py
 - docs/qa/T-0331-godot-import-crash.md
 - tasks/T-0331-ci-godot-import-crash.md
revision: 1
---

## Goal
Make the two CI jobs that export Android (`Android prototype debug APK`, `Android release resource
inspection`) reliable on `main`, and make every CI job run on one exact, immutable toolchain image.
Today `main` goes red at random for reasons that are not in the diff, which trains everyone to ignore red.

## Context
- AGENTS.md — "Engine: Godot 4.7 (one exact 4.7.y build in the Docker image, CI and exports)".
- AGENTS.md S8 — "Tests unrelated to your change fail on clean `main`. Report; do not fix." This task is
  the report-and-fix for the failure below.
- Evidence (runs on `main`, 2026-10-13, all `ci` workflow):
  - run 38447460132 (T-0330): release-inspection died with `double free or corruption (fasttop)` while
    reimporting `level.csv`.
  - run 38441760356 (T-0240): release-inspection died with `realloc(): invalid next size` while
    reimporting `ui.csv`.
  - run 38423735438 (T-0236): debug-APK job failed with exit code 1; the last 25 log lines contain only
    job cleanup, so the cause is not yet known.
  - Adjacent runs (e.g. 38444524601, 38433135739, 38431226824) were green on unrelated diffs.
  - The same `godot --headless --path game --import --quit` passes in `godot-import + test` in every run.
- `docs/qa/T-0138-release-export.md`, `docs/qa/T-0137-android-debug.md` — current export procedure.

## Current state
- `.github/workflows/ci.yml`
  - every job uses `container.image: ghcr.io/krystiangaleczka-tech/world-of-words-toolchain:latest`
    (a floating tag, 14 jobs).
  - `android-build` runs `tools/android_debug_build.py --templates /root/.local/share/godot/export_templates/4.7.2.stable`.
  - `release-inspection` runs `tools/check_release_export.py ... --export`.
- `.github/workflows/toolchain-image.yml`
  - pushes `:latest` and `:sha-<7>` on every merge to `docker/**`. `:sha-*` tags are not used by CI.
- `docker/Dockerfile` pins `ARG GODOT_VERSION=4.7.2`; the version is exact inside the image, but which
  image CI gets is not.
- `tools/android_debug_build.py` and `tools/check_release_export.py` each start with a full
  `godot --headless --path game --import --quit` on a fresh checkout (no `.godot/` cache), then export.
  A pinned-version check exists only in the debug script.
- `game/locale/{debug,gallery,level,ui}.csv` with `.csv.import` files exist; the crash is in the CSV
  translation importer during the first, cold import.

## Specification
### Behavior
1. **Pin the image.** CI references the toolchain image by immutable digest (or an equivalent that cannot
   move), not `:latest`. `toolchain-image.yml` must still publish `:latest` for local use. Updating the
   pin is a one-line change that is reviewed like any other. Document how to bump it in the QA note.
2. **Capture the failure.** When an import/export step is killed by a signal or exits non-zero, the job
   uploads the full Godot output, the exit code/signal, the Godot version string and the image digest as
   an artifact (`if: always()`). The debug-APK job must print the failing command's own output, not only
   the cleanup lines.
3. **Find out whether it reproduces.** Add a temporary, clearly named workflow_dispatch job (or script
   mode) that runs the cold `--import --quit` N times (N ≥ 20) on a fresh checkout and on the pinned
   image, and report the failure rate in the QA note. Remove or keep it manual-only before merge.
4. **Root cause.** Using the evidence, state in the QA note which of these it is, with the proof that
   rules the others out: (a) Godot 4.7.2 CSV translation importer bug under a cold cache, (b) parallel
   or repeated import in the same project directory, (c) runner memory/disk pressure, (d) something in
   our CSV content. If (a): link the upstream issue or write the minimal reproduction.
5. **Mitigation, only after 4.** If the cause is an engine bug that cannot be fixed here, choose the
   narrowest mitigation that is visible and bounded, for example: run the cold import once as a separate
   step so a crash there is retried exactly once and logged as `RETRIED`, then export on the warm cache.
   A silent or unbounded retry is not acceptable; a retry that fires must be reported in the job summary.
6. Both Android jobs share the same import/version-check code path so they cannot drift again.

### Edge cases
| Case | Expected |
|---|---|
| Import crashes twice in a row | Job fails, artifact from behavior 2 is uploaded, no third attempt |
| Import crashes once, then succeeds | Job passes, summary says `RETRIED`, artifact kept |
| Image digest no longer exists in GHCR | Job fails at container start with the digest in the message (acceptable; fix is to bump the pin) |
| Godot version differs from `4.7.2` | Both scripts fail with the pinned-version error |

## Out of scope
- Upgrading Godot, changing `project.godot` or export presets (S7).
- Rewriting or reformatting the locale CSVs (touching them is out of scope unless behavior 4 proves (d);
  then stop and escalate).
- Signing, secrets, keystores (S11); iOS jobs.
- Making unrelated CI jobs faster.

## Tests
File: `tools/tests/test_release_export.py`, `tools/tests/test_android_debug_build.py`
- `test_import_retried_once_is_reported`: given an import runner that fails once then succeeds, then the
  step passes and the summary contains `RETRIED`.
- `test_import_failing_twice_fails_without_third_attempt`: given a runner that always fails, then exactly
  two attempts are made and the error includes the captured output.
- `test_version_check_shared`: given Godot reporting `4.8.0.stable`, then both entry points reject it with
  the same error.
- `test_signal_exit_is_named`: given exit code -6, then the report names SIGABRT.
Workflow-level checks (digest pin present on every job, no `:latest` in `ci.yml`) are verified by the
reviewer and by `python3 tools/tasks.py lint` plus a grep recorded in the QA note.

## Acceptance
- All tests above exist and pass; `make check` is green.
- No `:latest` remains in `.github/workflows/ci.yml`.
- QA note contains: the reproduction rate, the stated root cause with evidence, the chosen mitigation
  and why it is bounded.
- Five consecutive `main`/PR runs after merge have both Android jobs green, or the QA note says what is
  still failing.

## Implementation notes
- Prefer fixing the cause over retrying. Retrying is the fallback for a confirmed upstream bug.
- Run the repro loop on `ubuntu-24.04` with the pinned image only; do not compare against a different
  Godot build in the same task.
- Keep the diff under ~300 lines; if behavior 4 needs a larger change, split it into a follow-up task.

## Escalation log
<!-- rule id → question → answer (revision N) -->
