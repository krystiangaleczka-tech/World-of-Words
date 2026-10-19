---
id: T-0355
title: Score difficulty from explicit immutable configuration
epic: E22
type: contract
area: pipeline.scoring
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0354]
touch:
  - pipeline/src/wordgame_pipeline/scoring/__init__.py
  - pipeline/src/wordgame_pipeline/scoring/model.py
  - pipeline/tests/scoring/test_model.py
  - docs/contracts/scoring.md
  - tasks/epics/E22-content.md
  - tasks/T-0355-configured-scoring.md
revision: 1
---

## Goal
Implement the independent configured scorer from ROADMAP T-0298. No unapproved
production weights or stage activation; fixture weights demonstrate mechanics only.

## Current state
Preflight main8be7af7: T-0354 exposes FEATURE_NAMES and extract_features with12 raw
finite nonnegative floats. config.parse_json rejects duplicate/nonfinite JSON and
canonical_bytes provides stable serialization. No scorer/config/production weights.

## Interface
ScoringConfig.from_dict(data), load_scoring(path:Path)->ScoringConfig,
score_features(features:Mapping, config:ScoringConfig)->DifficultyScore.
Frozen FeatureRule(name,weight,minimum,maximum,direction), ScoringConfig(rules:tuple),
FeatureScore(name,raw,normalized,contribution), DifficultyScore(total,config_sha256,
features:tuple). Direct public constructors enforce the same invariants as parsing.

## Specification
- Version1 JSON-compatible YAML object exactly {schema_version:1,features:{...}}.
  Feature map contains exactly FEATURE_NAMES; every rule has weight/minimum/maximum/
  direction. Strict finite nonnegative numeric weight/min/max (no bool/coercion),
  minimum<maximum, direction=higher|lower, at least one positive weight. Reject
  duplicate/missing/extra/malformed fields. Immutable config has canonical name order.
- Load only explicitly supplied file, ValueError diagnostics; no implicit default,
  production config, network or fixture file writes. to_dict returns independent
  normalized version1 shape; SHA256 of canonical config bytes identifies scoring.
- Require exact raw feature keys and finite nonnegative numbers. Clamp each raw
  measurement to rule bounds, normalize to[0,1], invert lower direction, then
  nonnegative weighted mean to[0,1]. Zero weights contribute0. Each immutable
  explanation records raw, normalized, weighted contribution; total is their stable
  sum with rounding bounded to[0,1]. Avoid overflow from large finite weights by
  scaling weights before normalizing. Invalid input never yields partial scores.
- Input key ordering does not affect report/hash; edits to caller-owned input or
  copied config never change a previously created config/result. No mutation of
  extracted features, level/difficulty/slots, P1 handlers, CLI or existing validators.

## Tests
Hand-calculated mixed directions/weights/contributions; min/max/saturation/zero
weights; extreme finite weights; immutable constructors/copies/hash/permutations;
all malformed rule/config/raw inputs incl bool/NaN/inf/overflow, duplicate keys and
missing file; real extractor integration and monotonic changes; full checks,
fresh review and exact-head CI. No UI or production-content approval claimed.

## Rollback
Squash revert removes unactivated scorer; no content or persistent data changes.
