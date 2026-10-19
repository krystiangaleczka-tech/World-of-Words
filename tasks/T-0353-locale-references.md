---
id: T-0353
title: Audit static localization references and shipped travel copy
epic: E21
type: feat
area: locale
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0352]
touch:
  - tools/check_locale_references.py
  - tools/tests/test_check_locale_references.py
  - docs/contracts/localization.md
  - docs/qa/T-0353/**
  - tasks/epics/E21-settings.md
  - tasks/T-0353-locale-references.md
revision: 2
---

## Goal
Complete the bounded automated T-0289 wave by detecting static key typos and
checking named travel metadata against bilingual copy. Do not claim human approval.

## Current state
Preflight main13323de: T-0351 validates347 keys, T-0352 proves imported parity.
Existing ui_checks only checks literal tr calls in features/components. GDScript
parser helpers walk/string/call and scene_errors exist. Source scopes features,
ui and services contain key assignments/maps and dynamic families. Shipped
content/pl/manifest.json is a legacy65-slot campaign with no named travel metadata.
ContentCatalog permits legacy manifests and requires grouped regions/locations/
landmarks when named metadata exists. Postcard derives location.<id>.fact, with
explicit pending copy when missing. No static reference/travel-copy audit exists.

## Specification
- Add readonly CLI tools/check_locale_references.py --root/--json (default root
  independent of cwd), using T-0351 catalog. Require all three source directories
  and at least one shipped manifest. No fixture/generated-content changes.
- Parse production .gd in features/ui/services with existing GDScript AST (ignore
  comments). Check literal tr/TranslationServer.translate calls, literal assignments
  to closed UI key fields (title/body/text/caption/a11y/label/sublabel/locked_label/
  action/message *_key), and three-part literals rooted in an existing locale area
  (including constant maps). Empty optional key fields are allowed. Static scene
  text uses existing scene_errors; literal *_key scene fields also require a key.
  Unknown key/parse/read errors fail with stable path/line diagnostics.
- Report literal key references and dynamic prefixes/templates separately. Dynamic
  key expressions are explicitly NOT fully resolved/certified; do not execute code,
  expand arbitrary strings, add suppression lists or claim full dataflow analysis.
- For every shipped */manifest.json: legacy metadata-free records report legacy
  (not approved names/facts). When named metadata exists require grouped nonempty
  regions/locations arrays, landmarks array, each region/location name_key in bilingual catalog;
  landmark entries retain the existing slot/landmark record shape with a boolean
  landmark flag, no invented name_key; numeric slot ranges remain outside this audit;
  location IDs must be nonempty strings and each derived fact key must exist in
  catalog OR be reported pending, matching current runtime fallback. Malformed
  metadata fails closed. This is copy-reference validation, not content schema,
  slot/hash/artwork validation or editing the existing pipeline validator.
- Deterministic JSON lists counts/static references/dynamic expressions/metadata
  and pending facts; default summary. Return nonzero on any error. Existing tools
  pytest runs actual repository audit in make check/CI. Store actual JSON evidence
  and a short review guide, with Chris's wording/plural/named-content gates open.

## Tests
Valid constants/maps/key assignments/calls/scenes; missing keys in each context,
unknown-area explicit UI keys; comments/non-key identifiers/empty optional fields;
dynamic prefixes reported without false failure; parse/read/missing scope/catalog/
manifest errors; named metadata missing names/invalid shapes and optional facts;
legacy report, deterministic actual repository snapshot, CLI cwd/no writes/error.
Full check, fresh review, all exact-head CI including Android.

## Out of scope
Translation wording approval, executing dynamic keys, UI changes, generated content,
manifest schema or pipeline-validator changes, EN content and native/device claims.
