# T-0331 Save v4 and compatibility boundary

Baseline checked against remote main4930733 (T-0330 PR165), not stale local T-0231. Baseline
472GUT passed. This implements only split1 of the owner-approved T-0330 contract; T-0242 and
ProgressCommitPort remain unavailable. Version readiness is not atomic/P2 capability evidence.

SaveSchemaV3 freezes the previous validator, canonicalizer and defaults. Historical2→3 uses it.
SaveSchema v4 adds only Save-owned inert atomic {lineage,revision,processed} and per-language
location_stars. The pure3→4 upgrade never loads Content, allocates stars/unlocks, grants rewards,
changes snapshots/purchases/other languages, or emits side effects. Historical globals remain
unallocated. Existing local credits survive if structurally valid and total≤global stars; all sums
are checked before addition. Reserved atomic collisions reject even if they look like v4 metadata.

Save selects a valid blocked v3 (including valid intermediate from v1/v2) at the same recovery
priority before considering later copies. It retains identity/wallet/items/legacy extensions, emits
no corruption event, does not rewrite originals on load, and reports needs_migration. Explicit P1
settings/section writes and debug reset continue against the frozen v3 schema; temp/backup promotion,
interrupted writes and retries retain the existing recovery protocol. Invalid v3 still falls back.
Migration state is unconfigured/needs_migration/ready for version handling only.

V4 structural validation checks closed atomic/proof fields, safe counts, canonical physical and
completion identity, lower-case SHA256 hashes, lineage and proof revision bounds, copied JSON-safe
snapshot/delta dictionaries and notification dictionaries. This is not owner authorization or
receipt verification: leases, processed proof issuance, joint commit/recovery, mutation revision/
reset lineage protocol and semantic context verification remain split2/3. Metadata is inert until
that backend exists; no boot wiring or new stub claims availability. Nonsequential historical
progress is preserved and remains subject to future fail-closed P2 adapter checks.

Nine new tests cover exact goldens/defaultchain, multilingual populated losslessness and no backfill,
local-credit/collision rejection, numeric/proof field validation, primary/temp/backup compatibility
and reopen/P1 writes/reset, temp interruption/retry, invalid-v3 fallback, and oldv1/v2 intermediates.
Existing v1/v2/v3 goldens are untouched. Existing v3 tests explicitly use frozen historical schema;
current-version chains/fresh/storage checks track VERSION and every future intermediate step.
No assertion/test count removed. Pure historical v1→v2 and2→v3 goldens remain explicit.

Pinned4.7.2 GUT481/481 and full make check, task/scope lint, fresh exact-head reviewer/checklist
and all CI checks required before merge. The frozen schema duplication is intentional to avoid
changing valid legacy reads when future schema requirements evolve. Rollback after writing v4
must retain a v4 reader, not merely lower VERSION. No hardware fsync guarantee is claimed.
