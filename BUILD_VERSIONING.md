# Android build versioning

Every local Android Debug APK build and Android Release resource export asks for
the current task ID (`T-NNNN`), the exact task title and the build date/time. The
task ID and title must match the task branch (or the latest task commit when on
another branch). Enter the timestamp in ISO 8601 form with a timezone offset,
for example `2026-10-11T14:30:00+02:00`. Blank or invalid values stop the export
before Godot starts.

GitHub Actions reads the task ID from the active task branch or commit subject,
uses the title in the matching `tasks/T-NNNN-*.md` file, and records the runner's
build start time. The export fails if it cannot identify that task.

Each export appends one record, including the build kind, to the ignored file
`builds/build-versioning.json`. The debug APK verification report and release
inspection report include the same record. CI uploads the versioning file with
each corresponding artifact. Inspecting an already-created release ZIP does not
create a new build record.
