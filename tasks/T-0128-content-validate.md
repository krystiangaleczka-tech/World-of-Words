---
id: T-0128
title: Validate shipped campaign content through one CI entry point
epic: E08
type: infra
area: ci
risk: high
executor: sol
think: med
ui: none
status: done
depends_on: [T-0127, T-0039]
touch:
  - pipeline/src/wordgame_pipeline/content.py
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/tests/test_content.py
  - Makefile
  - .github/workflows/ci.yml
  - docs/CONTENT.md
  - docs/qa/T-0128-content-validate.md
  - tasks/T-0128-content-validate.md
revision: 1
---

## Goal
One `wg validate-content` command validates shipped content locally and in CI;
future release-lock checks can be added behind that entry point without CI edits.

## Current state
T-0127 and T-0039 are done. CLI builds/export stages; SchemaRegistry and
validate_level provide shared structure/word/geometry checks. No shipped campaign
exists yet. Makefile content-validate currently skips an obsolete placeholder path;
CI has nine checks and no content check. Native tier artifacts are ignored.

## Specification
1. Add validate-content with --lang pl, --root pipeline and --content-root game/content.
   Validate canonical manifest/pack bytes, safe filenames, exact hashes/ranges,
   contiguous IDs/slots, shared schemas and complete levels through validate_level.
   Enforce P1 ordering, handmade onboarding, difficulty 0.0 and 100-slot word spacing.
   Fail on missing/extra/corrupt/symlink/special files and stale source evidence.
2. CI cannot download or retain the full source dictionary. Add --prepare-evidence:
   read the current canonical pinned tiers artifact and generate a compact canonical
   pipeline/content-evidence/pl.json containing all eligible forms for the shipped
   wheels, their authoritative tiers, manifest SHA and config/source/annotation/
   override/handmade provenance. Use this committed generated evidence in ordinary
   validation; record its trust boundary (reproducible extraction, not raw-source
   reannotation in CI). Preparation validates all levels and publishes evidence only
   on success. T-0131 creates the actual evidence with its generated content.
3. Before initial content exists, absence of both evidence and language directory
   prints explicit SKIP. Presence of either requires the other. No silent skip once
   content/evidence exists. Normal validation is read-only and has no network calls.
4. Replace Makefile placeholder with the command; add a dedicated CI job unconditionally
   running make content-validate. Do not change other jobs or runtime behavior.
5. No released-slot lock yet, dependencies, schema edits or invented player content.

## Tests
pipeline/tests/test_content.py: valid prepared evidence and read-only repeat;
missing-content phase behavior; stale source/config/override/handmade/manifest
provenance; malformed schema/hash/ranges/IDs, formability/bonus/geometry/spacing,
unmanaged/symlink/special files; CLI error reporting, atomic evidence on failure.

## Acceptance
make check, task/scope lint, fresh independent review and all ten CI checks.

## Rollback
Revert command and wiring. No runtime saves or content change in this task.
