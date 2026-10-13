---
id: T-0331
title: Save v4 lossless migration with frozen v3 compatibility
epic: E16
type: contract
area: services.save
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0330]
touch:
  - game/services/save.gd
  - game/services/save/save_schema.gd
  - game/services/save/save_schema_v3.gd*
  - game/services/save/save_migrations.gd
  - game/services/save/migrate_v2_to_v3.gd
  - game/services/save/migrate_v3_to_v4.gd*
  - game/tests/fixtures/save/v4.json
  - game/tests/integration/test_save_v4.gd*
  - game/tests/integration/test_save_v1.gd
  - game/tests/integration/test_save_v2.gd
  - game/tests/integration/test_save_v3.gd
  - docs/qa/T-0331-save-v4-migration.md
  - tasks/T-0330-atomic-save-economy-contract.md
  - tasks/T-0331-save-v4-migration.md
revision: 2
---

## Goal
Implement split1 from the owner-approved T-0330 contract. Atomic/P2 activation remains unavailable.

## Current state
Fresh main4930733 contains merged T-0330/PR165, SaveSchema v3, default1→2→3 migrations, existing
SaveStorage recovery and P1 dirty writes. Valid v3 migration failures currently fall through to
backup/fresh, which cannot preserve namespace collisions. ProgressCommitPort remains unavailable.
No atomic owner coordinator or lease API exists. Reconcile merged T-0330 status to done.

## Specification
1. Freeze exact existing v3 validator/canonicalizer/fresh template in SaveSchemaV3. Historical2→3
   migration uses it rather than future-version constants. SaveSchema VERSION4 adds only
   meta.atomic={lineage:0,revision:0,processed:{}} and per-language location_stars={}.
2. Pure MigrateV3ToV4.migrate validates frozen v3, rejects any existing meta.atomic extension,
   deep-copies every legacy field/extension, preserves existing structurally valid local stars or
   adds empty maps. Local counts nonnegative safe ints; sum≤global stars without overflow. No Content,
   star allocation, unlock copy, reward, retroactive grant, events or boot/P2 wiring. Full defaultchain.
3. V4 structural atomic metadata validates safe nonnegative lineage/revision and processed proof map.
   Proof fields follow T-0330: operation_id/request_hash/lineage/revision/language/slot/context_hash/
   committed_snapshot/delta/economy_snapshot/notifications; all snapshots/deltas JSON-safe dictionaries,
   notifications array of dictionaries. Closed atomic/proof shape; valid SHA256 hashes, canonical
   campaign_complete language/slot ID and physical key <lineage>:<operation_id>, proof current lineage
   and positive revision≤document revision. Owner/receipt authorization is NOT a schema predicate;
   semantic approval/proof verification is a later separately scoped backend task.
4. Save.migration_state()->String: unconfigured before load; ready for structurally validv4;
   needs_migration for validv3 that cannot upgrade. At each primary/temp/backup priority, preserve a
   validv3 original in compatibility mode before considering another file. No corruption event,
   clean replacement or identity generation solely due to blocked migration. A validv3 intermediate from v1/v2 is preserved likewise, without rewriting on load.
   P1 reads/writes/settings/
   debug-reset validate/canonicalize against loaded version and persistv3 preserving collisions.
   Existing recovery/promotion/error/retry semantics and signatures remain intact. Originals are not
   changed by load. Bad v3 still follows existing corrupt recovery. Version readiness is NOT P2-ready.
5. Atomic metadata stays inert in this split: no lease, processed proof writer, revision/lineage
   mutation protocol or boot coordinator exists yet. Those competing-writer/reset/receipt rules are
   split2; Economy/real port is split3, then T-0242. Existing unavailable P2 APIs remain unchanged.
6. Addv4 golden; historicalv1/v2/v3 goldens unchanged. Update listed existing tests only for explicit
   historical validators vs current default chain/fresh version; retain assertions and count. Generic
   future migration test remains VERSION+1 and registers every intervening pure version step.

## Tests
Golden v3→v4/defaultchain; populated languages/earned wallet/purchases/retired IDs/extensions unchanged;
existing local credits preserved, invalid/sum overflow/collision rejected; numeric canonicalization,
metadata/proof malformed fields and identity/hash/revision checks; validv3 blocked primary/temp/backup
reopen/P1 settings/progress writes and reset preserve data; interruption retry promotes originalv3;
invalidv3 falls back; semantically nonsequential progress preserved without P2 activation/grants.
Full make check, lint/scope, fresh exact-head independent reviewer/checklist and all CI before merge.

## Rollback
Retainv4 reader support after release; do not downgrade VERSION blindly. Legacy backups survive writes.
