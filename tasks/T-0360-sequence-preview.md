---
id: T-0360
title: Compose a readonly sequence preview with fresh scores and provenance
epic: E22
type: feat
area: pipeline.sequence
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0359]
touch:
  - pipeline/src/wordgame_pipeline/sequence/preview.py
  - pipeline/tests/sequence/test_preview.py
  - docs/contracts/scoring.md
  - tasks/epics/E22-content.md
  - tasks/T-0360-sequence-preview.md
revision: 1
---

## Goal
Complete the bounded T-0300 planning wave with an explicit readonly JSON preview.
Bind candidate scores to one scoring configuration and source-level hashes; never
claim publishing readiness or replace CONTENT.md#slot-policy release locks.

## Current state
Preflight main ed6c0b4: sequence.allocate.allocate returns immutable allocation or
AllocationError(code,slot,blocked,conflicts); sequence.slots provides Region,
Location, Reservation and SlotPlan. CurveConfig.from_dict and ScoringConfig.from_dict
validate explicit version1 configs. scoring.features.extract_features validates
geometry/exact ARF maps and scoring.model.score_features returns explanations.
config exposes parse_json/canonical_bytes/load_config; validate.schema exposes
json_value and SchemaRegistry(root).validate_schema("level", level). No preview
module/command exists. Release lock enforcement remains a later T-0301/T-0302 gate;
older planning notes about export lock authority are normative, not proof of an
implemented lock verifier. All shipped prototype levels are authored.

## Specification
- New sequence.preview.preview(data:object)->dict consumes finite strict JSON:
  exact schema_version=1, language="pl", scoring, duplicate_policy, plan, candidates.
  Plan has exact regions/locations/authored/released arrays mapped to existing frozen
  constructors. Candidate has exact id,level,frequencies,seed_word. Missing/unknown
  fields, duplicate JSON keys, nonfinite numbers and malformed types fail closed.
- Validate every supplied exported level against the existing local level schema
  and geometry; require entry ID=level ID=pl-c-NNNNNN with matching positive slot.
  For fixed authored/released IDs require source slot=reserved slot. Derive authored
  solely from source=handmade and landmark from source level, never caller flags.
- Recompute features and scores for every candidate under the one explicit scoring
  config; ignore old difficulty. Require explicit selected seed and exact-form ARF
  map. Use existing allocator/policy with no constraint relaxation/input mutation.
- Return canonicalizable deterministic version1 report: planning-preview scope,
  status ok/blocked, request/language config/local schema/scoring config SHA256,
  sorted per-candidate source SHA256 and complete fresh scoring explanation,
  ordered assignments with requirements/selected ID/difficulty/mode/deviation/
  rejections and sorted unused IDs. No timestamps/absolute paths or source writes.
- AllocationError becomes a blocked report with code/slot/rejections/conflicts,
  assignments=[] and unused=[]; never expose a partial plan or claim global
  unsatisfiability. Invalid request remains ValueError, not a blocked allocation.
- Report explicitly lists unverified released geometry, tier/bonus/source approval,
  seed provenance and production calibration. Source/seed declarations and hashes
  establish input identity, not human approval or released geometry lock proof.
- CLI: python -m wordgame_pipeline.sequence.preview INPUT.json reads only explicit
  input and package-local schemas/language config, independent of cwd. Canonical
  JSON stdout and exit0=ok/2=blocked. Invalid input: exit1, diagnostic stderr, no
  stdout. No output option, files written, stage activation, network or new deps.

## Tests
Fixture integration from existing levels (generated flags changed in memory only):
fresh score/explanations, unchanged input/shipped bytes, fixed slots/source evidence,
repeat/key-order determinism and hashes sensitive to inputs; exact fields/types/
version/language/ID/slot/source/ARF/seed/schema/geometry errors; blocked allocation
has evidence and no partial assignment; CLI from unrelated cwd covers exits0/2/1,
canonical stdout, duplicate JSON keys/nonfinite/missing file and no output writes.
Full check, fresh pack-only review, exact-head CI before merge.

## Out of scope
Production parameters/content generation, human/AI source approval, seed discovery,
release locks, tier/bonus semantic certification, export/validator/handler changes.

## Rollback
Revert removes an unused planning command; published content and game are unchanged.
