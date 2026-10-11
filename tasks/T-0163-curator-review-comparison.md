---
id: T-0163
title: Validate candidate judgments and report review changes
epic: E08
type: feat
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0162]
touch:
  - pipeline/src/wordgame_pipeline/review_comparison.py
  - pipeline/tests/test_review_comparison.py
  - tasks/T-0163-curator-review-comparison.md
revision: 1
---

## Goal
Validate candidate judgments and report review changes. Owner requested five more tasks before the pending P2 human gate.

## Current state
build_report validates content before joining annotations; load_catalog and early_issues exist. New comparison/test do not exist.

## Specification
Add compare_reviews(root: Path, content: Path, baseline_path: Path, candidate_path: Path) -> dict. Build baseline report, validate candidate with native WordIndex and require exact current required-word coverage (no dropped/extra words). Return schema_version1, inputs baseline_sha256/candidate_sha256/tiers_sha256/packs, candidate coverage, Unicode-sorted changes [{word,before,after}] with five WordReview fields (missing before uses report fields), and early_check slots15/max_band2/issues. Hashes identify bytes, not curator identity. Report declared judgments and changes; do not authenticate identity, edit files, apply catalog, infer approval, change sources/content or phase status.

## Tests
Test unchanged current catalog/no changes/24 proposed issues, explicit reviewed fixtures/diff/reasons, hashes and canonical-serializable shape, missing/extra/unknown/banned/malformed candidate rejection, tampered content rejection, read-only tree/nonmutation and retained proposal statuses.

## Acceptance
Only authorized touch files; full make check, scope/count, independent fresh review
and final-head green CI before squash merge. No human review or phase result invented.

## Outcome
Read-only source-backed comparison passes nine focused cases. Full make check:
247 GUT / 13049 assertions, 301 pipeline, 142 tools, 65 levels. Scope three
files; count434 vs428. Fresh review approved d6490b486be1ded8e317cb7940f4198341a3de7d.
Current catalog remains proposed; unchanged comparison retains24 early issues.
Final-head green CI required before squash merge.
