# T-0132 — automatic P1 locale registration

Boot owns a LocaleCatalog that discovers imported translations through
ResourceLoader.list_directory, duplicates them, and registers the complete
catalogue before navigation mounts a screen. Each owner releases only its own
copies. Failed discovery/loading registers nothing; repeated registration is
idempotent and failure can retry. The existing Level/Debug owners still support
standalone screens and tools.

Nav loads the saved language and validates the first level before setting the UI
locale and mounting its screen. Missing manifests or unavailable first packs keep
the previous locale and leave navigation on BOOT. Save format and public APIs
remain unchanged.

Current per-area level.csv/debug.csv retain English keys and PL/EN columns. Debug
Polish copy changes only Home → Menu and Wersja contentu → Wersja poziomów; English
values and key meanings are preserved. No screen geometry, components, tokens or
theme change. Integration assertions verify both actual areas, CSV conventions
and first-screen Polish copy. Native-speaker/device approval is not claimed.

Eight new GUT tests cover a newly imported area without project entries, actual
PL/EN copy, idempotence and cleanup, other-owner preservation, atomic failure and
retry, key/header/value conventions, real boot ordering and saved locale, missing/
empty directory errors, and failed navigation including a missing first pack.

A temporary, separate Godot project imported the real per-area CSVs, used the
unchanged LocaleCatalog and exported a Linux all_resources PCK. Running from that
PCK reports successful registration and Polish Narzędzia debugowania, while raw
debug.csv has zero accessible bytes. Thus runtime discovery uses exported compiled
resources, not source CSV parsing. The repository's project.godot/export settings
are untouched; platform presets remain T-0135. Probe logs are local artifacts:
/tmp/t0132-pack-import.log, /tmp/t0132-pack-export.log, /tmp/t0132-pack-probe.log.

No component/state was added or changed for a gallery screenshot. Text behavior
is covered in PL/EN integration tests; CI gallery capture remains T-0327. No
device screenshot or device test is fabricated.

Task dependency preflight corrected an initially incorrect T-0051 completion claim. As with T-0120, current explicit prototype-continuation authorization uses actual delivered Nav/Debug/Level prerequisites; ROADMAP and unperformed human phase-exit gates are unchanged.

Full make check passes: 207 GUT tests (8,250 assertions), 199 pipeline tests and 81 tools tests; all 65 shipped PL levels validate. Task metadata lint passes 87 tasks. Fresh independent review and all remote CI jobs are merge gates.

Fresh independent review APPROVE at 7010e85b600a8501783ca9caee07282da0d407d4. Reviewer verified catalogue ownership/atomicity, real boot ordering, saved locale and failed-first-pack behavior, copy/keys, scope/dependencies, fullcheck evidence and the matching exported PCK probe. No blockers; remote CI remains the merge gate.
