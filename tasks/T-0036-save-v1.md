---
id: T-0036
title: Implement atomic Save v1 and recovery contracts
epic: E03
type: contract
area: services.save
risk: high
executor: sol
think: xhigh
ui: none
status: done
depends_on: [T-0034]
touch:
  - game/services/save.gd*
  - game/services/save/**
  - game/services/events.gd*
  - game/tests/fixtures/save/v1.json
  - game/tests/integration/test_save_v1.gd*
  - tasks/T-0036-save-v1.md
revision: 1
---

## Goal
Provide Save v1, atomic replacement, recovery, identity and pure migration framework for later services.

## Context
- ARCHITECTURE.md#save: primary -> temp -> backup on load; temp/flush/backup/promotion on write.
- PRODUCT.md FR-SAVE-01..05, FR-SAVE-07 and NFR-13; ROADMAP T-0036.
- ARCHITECTURE.md#autoloads: settings/meta belong to Save; other sections belong to their services.

## Current state
Original implementation used T-0034 PR #21; it is now merged. T-0035 is also merged on main.
Save/Events are inert ServiceStub scripts; Clock is injected at boot; GUT discovers integration tests.
No save, migrations or golden fixture exist on the dependency branch.

## Specification
### Behavior
1. Persist the exact v1 structure and defaults shown in ARCHITECTURE.md; independent copies per save.
   Fresh meta has random UUID v4 install_id, injected UTC created_at and project app version.
2. Structural validation rejects missing sections/known fields, wrong types, fractional integer fields,
   invalid UUID, non-JSON values and unsafe numeric precision. Unknown extension keys survive.
   JSON numeric fields are canonicalized back to declared int/float types before exposure.
   Domain/balance validation belongs to owning services. Nullable placeholders await their contracts.
3. Load primary, then temp, then backup; pure migrations precede structural validation and exposure.
   Missing/corrupt/newer-version/invalid candidates fall through. First install persists immediately.
4. If existing candidates all fail, create clean state and emit Events.save_corrupted once per load.
   Keep corrupt originals until explicit flush. Recovery emits Save.backup_restored once; UI is T-0295.
5. Temp write + flush + same-directory rename of valid current to .bak + temp to current.
   Do not rotate corrupt primary over a valid backup after recovery. Propagate I/O errors, keep dirty
   in-memory data for retry, emit flush_failed; synchronous flush OK is required before durable grants finish.
6. request_flush is synchronous to avoid a deferred durability window. Flush on application pause if loaded.
   No _process, per-frame writes, implicit boot load, SDK or gameplay/economy logic.
7. Expose deep-copy owner sections; refuse external changes to meta/settings. Closed settings accessors
   persist immediately and emit setting_changed only after success; failed change remains dirty for retry.
8. Migration framework registers one pure step per version; rejects duplicates, missing steps, malformed
   versions, future documents and steps that do not advance by one. v1 needs no historical migration.

### Interface
- Save.load() -> Error; flush() -> Error; request_flush() -> Error.
- Save.configure(SaveStorage, Callable = Callable()) -> void before load, for isolated tests.
- Save.get_section(StringName) -> Dictionary; set_section(StringName, Dictionary) -> Error.
- Save.get_setting(StringName) -> Variant; set_setting(StringName, Variant) -> Error.
- Signals setting_changed(key: StringName), backup_restored, flush_failed(error: Error).
- Events.save_corrupted (no arguments, side effects only).
- SaveStorage.read_document(String = "") -> Dictionary; has_any_file() -> bool;
  commit(String, bool) -> Error; checkpoint(StringName) -> Error (fault injection).
- SaveMigrations.register_step(int, Callable) -> Error; upgrade(Dictionary) -> Dictionary.
- SaveSchema.fresh(String, String, String) -> Dictionary; is_valid(Dictionary) -> bool;
  canonical(Dictionary) -> Dictionary; new_install_id(PackedByteArray = PackedByteArray()) -> String; VERSION = 1.

### Edge cases
Interrupted commit may expose the old committed document or the complete new one, never a partial JSON.
Invalid temporary file falls back to backup. Loading twice does not regenerate identity or re-emit recovery.
No save locations, signing, OS backup settings or schema versions beyond v1 are changed.

## Tests
File: game/tests/integration/test_save_v1.gd; golden: game/tests/fixtures/save/v1.json.
- Exact golden defaults, round trip, previous .bak, fixed identity and injected creation timestamp.
- Primary precedence; temp then backup; missing/newer/malformed version/shape/UUID candidates.
- All-corrupt clean start emits once and preserves originals before flush; recovered backup stays valid.
- Fault injection at temp-written, temp-flushed, backup-rotated and primary-promoted; reload and retry.
- Truncated temp; real file-open failure; section copies, owner boundaries and invalid values.
- Setting persistence/signals/failure; meaningful flush/background pause; pure chained migrations.
- Non-JSON, non-finite and unsafe integer values rejected; UUID v4 formatting with injected entropy.
Run pinned Godot 4.7.2 make check, lint/scope/test-count relative to T-0034 and headless smoke.

## Acceptance
All specified behaviors and integration tests pass; no existing tests changed.

## Rollback
Before release a revert is sufficient. Once v1 is shipped, future incompatible changes require a new
schema migration; never silently downgrade a released save format.

## Deviations / concerns
Dependency T-0034 merged in #21; T-0035 merged in #22. Source applied unchanged to fresh main
without conflicts and the combined contracts revalidated under Chris's sequential-merge instruction.
Fault tests exercise actual files and controlled stops/errors at write boundaries plus truncated data;
they do not prove filesystem durability across physical power loss (flush is not directory fsync).
The complete save contract and recovery tests exceed the ~300-line guideline; there are five production
scripts, with storage/schema/migrations separated for testability. Device kill testing remains follow-up.

## Completion record
2026-10-06: Chris explicitly instructed sequential merges. Dependencies are merged;
task marked done for authorized merge after combined-platform/save validation on fresh main.
