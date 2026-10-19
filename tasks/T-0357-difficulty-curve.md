---
id: T-0357
title: Calculate explicit regional difficulty targets and protected onboarding
epic: E22
type: contract
area: pipeline.sequence
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0356]
touch:
  - pipeline/src/wordgame_pipeline/sequence/**
  - pipeline/tests/sequence/**
  - docs/contracts/scoring.md
  - tasks/epics/E22-content.md
  - tasks/T-0357-difficulty-curve.md
revision: 1
---

## Goal
Extract ROADMAP T-0300 target calculation independently of content generation.
CONTENT.md#curve requires regional trend/saw-tooth, landmark spikes, easier next
slot and handmade slots1–15 outside the curve. No production defaults are chosen.

## Current state
Preflight main24d8fd0: explicit score and duplicate contracts are merged; no
sequence module or production curve config exists. Existing strict parse_json
supports JSON-compatible YAML. P1 handlers and shipped levels remain unchanged.

## Interface
Frozen CurveConfig(first,last,base,trend,period,amplitude,landmark_spike,
breather_drop,landmarks:tuple[int,...]), from_dict/to_dict, load_curve(path:Path).
target_for_slot(slot:int,config:CurveConfig)->frozen CurveTarget(slot,kind,target,
baseline). kind=onboarding|regular|landmark|breather. No range allocation/selection.

## Specification
- Version1 JSON-compatible YAML exactly schema_version plus config fields; explicit
  file only, no defaults. first/last positive integer manifest-safe<=2**53-1,
  last>=first; integer period>=2 and same safe bound. Numeric base/trend/amplitude/
  spike/drop finite0..1, no bool/coercion; spike/drop strictly positive. Frozen
  constructors validate too; to_dict returns independent lists/dicts.
- Landmarks supplied as unique slots within region, above15, before region.last;
  reject consecutive slots so every landmark owns an in-region breather. Parse
  order does not matter; canonical tuple order. No actual landmark slot is invented.
- Only calculate one requested in-region integer slot. Slots<=15 return onboarding
  with target/baseline=None: no generated target even under unusual fixture weights.
- For others offset=slot-first; saw=(offset%period)/(period-1). Baseline clamps
  base+trend*offset+amplitude*saw to[0,1]. Ordinary target=baseline; landmark target
  clamps baseline+spike. Breather target is min(baseline-drop,previous landmark
  target-drop), bounded below0. Ensure strictly below previous landmark even when
  tiny positive drop rounds away (nextafter toward0). Never recurse or allocate
  an entire region. Explain both target and ordinary baseline.
- Invalid config/file/slot fails ValueError, without input changes or partial
  target. Stable config roundtrip and input order; strict parser rejects duplicate
  keys/NaN. No dependencies, network, clock/RNG, config writes or pipeline activation.
- Document this is region-local target policy. No slot assignment/released lock,
  actual region/location mapping, production calibration or curve.yaml created.

## Tests
Exact trend/saw/reset and landmark/breather arithmetic; onboarding1–15; saturation
and tiny-drop strict recovery; region offsets/one-slot queries at huge safe bound;
immutable constructor/roundtrip/permutation; malformed numeric/types/regions/
landmarks/slots/file/duplicate JSON and nonmutation. Full check/fresh review/all CI.

## Rollback
Squash revert removes unused target calculation; no generated/persisted changes.
