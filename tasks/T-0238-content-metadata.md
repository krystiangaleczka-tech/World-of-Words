---
id: T-0238
title: Define additive manifest metadata and Content lookup contract
epic: E16
type: contract
area: services.content
risk: high
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0203]
touch:
  - pipeline/schema/manifest.schema.json
  - pipeline/schema/README.md
  - pipeline/src/wordgame_pipeline/validate/manifest.py
  - pipeline/src/wordgame_pipeline/content.py
  - pipeline/tests/test_manifest_metadata.py
  - game/services/content.gd
  - game/services/content/content_catalog.gd*
  - game/tests/integration/test_content_metadata.gd*
  - tasks/T-0238-content-metadata.md
  - docs/qa/T-0238-content-metadata.md
revision: 1
---

## Goal
Define additive manifest 1.1 metadata and tested slot/location/region queries while loading P1 unchanged.
Owner requested drafting and implementing the missing next task.

## Context
CONTENT.md#manifest: locations cover every slot without gaps/overlaps; P1 treats campaign as one
location. Regional metadata shipping remains T-0302; this task prepares schema/API only.
Roadmap T-0238, FR-PROG-03. No generated game/content files are edited.

## Current state
Shared manifest schema_version remains integer 1 and forbids unknown fields. P1 has packs/slots
but no regions, locations or landmarks. Content.load_manifest validates before replacing state;
level_for_slot lazily loads the current pack. Pipeline content.bundle uses SchemaRegistry and
validates ordered pack intervals/hashes/slot coverage. Existing schema harness supports allOf/if/then.

## Specification
1. Add optional all-or-none regions/locations/landmarks arrays to the same version-1 manifest
   (additive revision 1.1, no new version field). Regions: id/name_key/first/last.
   Locations: id/region/name_key/first/last/postcard/pieces; postcard is a safe postcards/*.webp
   asset identifier/path, pieces positive int capacity. Landmarks: sparse {slot,landmark:bool}
   records, omitted slots mean false. Preserve all existing P1 fields and schema identity.
2. Typed metadata: nonempty lower-case alphanumeric/hyphen IDs, journey region/location keys,
   positive safe-range integral counts (accept integral JSON numbers at boundary), bool flags.
   Closed entry shapes. Regions and locations independently form ordered partitions 1..slots;
   IDs unique within each list; location belongs fully to its referenced region. Landmark slots
   unique and in range. All-or-none fields; empty/partial/malformed metadata rejects atomically.
3. New ContentCatalog pure RefCounted copies and validates dictionaries; no Nodes/I/O/time/random.
   Content validates it before swapping manifest/cache. Expose regions()->Array[Dictionary],
   location_for_slot(slot)->Dictionary, region_for_slot(slot)->Dictionary, is_landmark(slot)->bool.
   Independent returned values. Before load/out-of-range return []/{}/false, no signals/pack I/O.
4. P1 fallback is one virtual campaign region/location spanning all slots (id and region campaign,
   empty name_key/postcard and pieces 0). This synthetic API value is never serialized as P2 metadata.
   Failed metadata reload keeps prior catalog and cached level. Successful reload replaces both.
5. Pipeline metadata validator performs the same semantic partitions/references/uniqueness checks
   after SchemaRegistry structural validation in content.bundle, before reading packs.
   This task explicitly changes only manifest validation; lexical/level validators unchanged.
   Shared schema documents structural versus semantic guarantees and T-0302 shipping boundary.

## Tests
New pipeline test_manifest_metadata.py: shipped P1 and valid additive shape; types/closed entries,
partial arrays, gaps/overlaps/duplicates/bad region references/path traversal/invalid landmark flags;
metadata semantic validation from content.bundle; input isolation.
New GUT test_content_metadata.gd: pre-load/P1 fallback, valid boundary lookups and copy isolation,
invalid atomic reload/cache preservation, successful replacement; JSON integral counts and invalid
fraction/bool values, no pack I/O for metadata queries. Full make check and scope/task lint.

## Rollback
No shipped P2 metadata: revert schema/API without touching generated packs or saved progress.

## Escalation log
S2: changing the manifest schema invalidates its hash in pipeline/content-inputs/pl.json.
Full make check failed 26 provenance-dependent tests; new metadata/schema tests and GUT tests passed.
Requested owner approval to refresh only this schema hash, preserving records/candidates and all
65 shipped level bytes, then replay/check the campaign. No hash receipt update made yet.
