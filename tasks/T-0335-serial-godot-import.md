---
id: T-0335
title: Serialize editor imports to avoid the pinned Godot CSV worker race
epic: E01
type: infra
area: infra
risk: medium
executor: sol
think: med
ui: none
status: review
depends_on: [T-0014]
touch:
  - game/project.godot
  - game/tests/integration/test_import_policy.gd*
  - docs/qa/T-0335/**
  - tasks/T-0335-serial-godot-import.md
revision: 1
---

## Goal
Fix recurring native Godot import crashes rather than relying on job reruns.
Explicitly requested by Chris after the T-0276/T-0284–0287 wave.

## Current state
Pinned Godot4.7.2 ed1daf0bf imports CSV resources on worker threads. Its
EditorFileSystem reads the ProjectSettings key editor/import/use_multiple_threads;
ResourceImporterCSVTranslation advertises threaded import support. The project
does not override that key. Repeated CI cold imports have failed in cowdata.h
with fatal indices, root propagate_notification from a worker, or heap corruption.
Failures precede GUT, while the same head passes after a targeted rerun.
Make import, toolchain smoke, Android exports and the theme checker all consume
game/project.godot; the theme checker copies it into a fresh-cache shadow project.

## Specification
Set the existing engine setting editor/import/use_multiple_threads=false under
[editor] in game/project.godot. This task explicitly authorizes that narrowly
scoped project-settings hotspot change. Do not change the pinned engine, runtime
thread policy, autoloads, exports, assets, importer implementation or CI error gates.
No retry, warning filter, successful exit masking or cache reuse as a substitute.

Add an actual-Godot integration policy guard that fails if the canonical key is
removed, renamed, non-boolean or enabled. Record the exact source references,
existing failure receipts, commands, timing and limitations in QA. In disposable
project copies excluding .godot, compare the previous parallel policy with serial
imports: bounded baseline attempts (stop after first reproduced failure), then
at least ten independent serial cold imports with strict return-code/log checks.
Never mutate/remove the working project's cache for the experiment. If baseline
cannot reproduce locally, state that honestly and retain the actual CI receipts.
Run full checks, fresh independent review and all CI including Android before merge.

## Tests
- Actual ProjectSettings canonical policy integration test.
- Independent fresh-cache serial stress runs, without retries inside an attempt.
- Compare imported translation output hashes across successful runs.
- Full make check; generated-theme clean-cache check; exact-head CI15 green.
