# T-0151 — diagnostic level playtesting

## Device reproduction and cause

On 2026-10-11, ADB connected to Chris's Samsung SM-S948B over wireless debugging.
The installed prototype had campaign current_slot 24. Reopening slot 21 through
diagnostics, shuffling three times, returning through diagnostics and selecting
BOA produced the translated persistence-error status and no found-word feedback.
Repeating without shuffling reproduced the same failure.

Progress correctly refuses to store an active-board snapshot for a slot other
than the campaign current slot. The controller treated a diagnostic playtest as
a normal campaign mutation, so that refusal prevented publication of a valid
word result and left the controller retrying the same pending mutation.

## Change

Controller configuration now defaults to normal persistent play and optionally
supports session-only play. In debug builds, LevelScreen selects session-only
play for non-current slots. Words, bonuses, hints and the completion screen work
without writing or moving campaign progress. Reopening such a slot starts fresh.
Current-slot persistence and retries, release behavior and the final campaign
resume screen are retained. No Save format, economy or content changes.

## Validation

- Full `make check`: 244 GUT tests, 199 pipeline tests, 142 tools tests;
  formatting, lint, import, registries and all 65 shipped levels pass.
- Four new regression tests cover shuffled return through diagnostics, an active
  campaign snapshot, bonuses, already-found feedback, hints, completion, pause,
  future-slot play, current-slot durability failure/retry and mode reconfiguration.
- Exact Godot 4.7.2 Android Debug APK and resource export verified by the existing
  Android tool. Packaged boot/audio/navigation smoke passed. Build metadata
  records T-0151, its exact title and timezone-aware date/time, using the pending
  T-0150 versioning helper without adding it to this task's scope.
- Device save.json and save.json.bak were backed up before the update and restored
  byte-for-byte. Chris progressed during development; the installation backup was
  at current_slot 63, not the earlier diagnostic baseline at 24.
- After Chris finished the campaign, the patched device was tested with saved
  current_slot 66 / highest_completed_slot 65. On reopened slot 21, three shuffles,
  diagnostic return and BOA gave found-word feedback and filled the grid. ABO
  gave bonus feedback/count 1; OBA filled the remaining cells and showed completion.
  The whole saved document was byte-identical before/after this test. No Godot
  error-level logs occurred. The device was returned to its completed slot 65.

Local device evidence: `/tmp/wow-device-check.1pdsk1/` contains before/after
screenshots and the recoverable pre-update save archive. APK and metadata are in
the task worktree's ignored `builds/` directory. No private save data is committed.

Chris's lexical-difficulty feedback, including WODA/DWA, less obvious inflections
and JAR, is recorded separately in `word-difficulty-feedback.md`. It is a future
content input, not a generated-content or classification change.
