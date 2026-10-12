---
id: T-0150
title: Require build versioning metadata for Android exports
epic: E09
type: infra
area: infra
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0137, T-0138]
touch:
  - tasks/ROADMAP.md
  - tasks/T-0150-build-versioning.md
  - BUILD_VERSIONING.md
  - tools/src/wow_tools/build_versioning.py
  - tools/android_debug_build.py
  - tools/check_release_export.py
  - .github/workflows/ci.yml
  - docs/qa/T-0150-build-versioning.md
revision: 1
---

## Goal
Record the task ID, task name and timestamp for every Android export. Local export
commands must collect the fields before building; CI derives the active task from
the task branch or commit and includes the same record with the artifact.

## Context
- `tasks/T-0137-android-debug.md` — pinned Android Debug APK build.
- `tasks/T-0138-release-export.md` — actual Android Release resource export.
- `AGENTS.md` — one task per branch and task-scoped changes.

## Current state
- `tools/android_debug_build.py` builds and verifies the Android Debug APK and
  writes `builds/android-debug-verification.txt`.
- `tools/check_release_export.py --export` creates the Android Release resource
  ZIP and optionally writes a JSON inspection report.
- `.github/workflows/ci.yml` runs both exports in separate jobs and uploads their
  reports; `builds/` is ignored by Git.
- No common build metadata prompt or versioning record exists.

## Specification
### Behavior
1. Add `BUILD_VERSIONING.md` documenting the required fields and timestamp format.
2. Before a local Android Debug APK or Release resource export starts, require the
   user to enter the current `T-NNNN` task ID, its exact task title and a
   timezone-aware ISO 8601 date/time. Reject values that do not match the current
   task branch (or latest task commit when on another branch) before export.
3. In GitHub Actions, derive the task ID from the active task branch or commit
   subject, read the matching task title from `tasks/`, and use the build start
   time. Fail the build if the task cannot be identified.
4. Write the metadata to `builds/build-versioning.json` and include it in the
   debug verification report and release inspection report. Upload the file with
   both CI artifacts. Inspection of an already-existing release ZIP without
   `--export` does not prompt for build metadata.

### Tests
No automated tests are added or run for this task. Review both export entry
points and the CI artifact paths against the acceptance behavior above.

## Acceptance
- A local export cannot start until task ID, task name and date/time are supplied.
- Both CI export artifacts contain task ID, task name, timestamp and build kind.
- Existing release ZIP inspection remains usable without build metadata.

## Rollback
Remove the versioning prompt, helper, report fields and CI artifact paths together.
