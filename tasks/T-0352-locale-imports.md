---
id: T-0352
title: Verify every imported bilingual translation and registration lifecycle
epic: E21
type: test
area: locale
risk: low
executor: sol
think: high
ui: none
status: review
depends_on: [T-0351]
touch:
  - game/tests/integration/test_locale_parity.gd*
  - docs/contracts/localization.md
  - tasks/epics/E21-settings.md
  - tasks/T-0352-locale-imports.md
revision: 1
---

## Goal
Implement actual imported-resource proof for ROADMAP T-0289/FR-LOC-03/04.
Source checks cannot detect stale imports or a wrong-language resource.

## Current state
Preflight main3b7377e:347 bilingual keys pass T-0351. LocaleCatalog.register_all
loads export-aware independent Translation copies and unregister releases its own.
Existing test_locale_catalog only samples real copy; no exhaustive source/import
comparison or whole-catalog locale-cycle parity exists. GUT is already in CI.

## Specification
- Add integration tests enumerating every actual area CSV and both corresponding
  imported resources. Require Translation type, correct resource locale and exact
  get_message(key) == CSV cell; never accept fallback/key echo as proof.
- Register actual catalog and cycle PL/EN and regional locales pl_PL/en_US repeatedly,
  comparing every translated key with exact source. Repeated registration must
  remain idempotent; restore global locale and pseudolocalization after each test.
- Format every current parameterized source/import message using values1,2,5,21
  and non-ASCII string arguments; source/import output must agree without engine
  format errors. Numeric percentage labels are not formatting expressions. This
  does not automate grammatical/plural/editorial approval.
- Controlled user:// two-language resources verify independent owners survive one
  unregister, outside translations remain, final owner releases, corrupt import
  cannot partially register and explicit repaired retry works. Deterministic
  fixtures are removed; no new runtime API, project setting or source copy change.
- Document exact scope and remaining human/native/content gates.

## Tests
New GUT suite covers all imported cells, all registered keys over locale cycles,
parameterized messages across four count values, independent and outside owners,
partial-failure rollback and retry. Pinned import/focused/full checks, fresh review,
all exact-head CI including Android. No UI change/screenshots required.
