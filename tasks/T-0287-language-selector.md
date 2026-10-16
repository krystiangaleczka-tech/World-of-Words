---
id: T-0287
title: Select shipped content languages with transient debug UI preview
epic: E21
type: feat
area: features.settings
risk: high
executor: sol
think: med
ui: high
status: review
depends_on: [T-0286, T-0242]
touch:
  - game/services/settings_language.gd*
  - game/features/settings/*.gd*
  - game/locale/settings.csv*
  - game/tests/integration/test_settings_language.gd*
  - game/tests/fixtures/settings/**
  - docs/qa/T-0287/**
  - docs/contracts/settings.md
  - tasks/T-0287-language-selector.md
  - tasks/T-0286-settings-apply.md
revision: 1
---

## Goal
Keep selected UI/content language coherent and every language's campaign intact.

## Current state
T-0286 has an explicit settings screen/runtime and first-install defaults hook.
Content.load_manifest preserves old content on failure. Only PL content ships;
EN translations exist. No language selector/controller. Contract T-0284.

## Specification
Explicit SettingsLanguage owner discovers valid shipped manifests from injected
content root, binds actual Save/Content and caller reload hook; no Nav/boot change.
Current PL is the only production choice; translations alone never unlock EN.
Settings binds selector explicitly and opens a catalog Sheet on language intent.
Native debug builds may show a clearly labelled transient EN UI preview only;
Save.language and Content.language remain unchanged. Production hides it.
Device initial locale resolves to a shipped base language or PL and feeds the
before-load Save default hook; never override an existing saved choice.
For real shipped alternatives, prepare/persist/reload through the caller hook,
retain per-language progress, reject unsafe owner reload, fail closed on I/O and
never claim success while reload is pending. Freeze exact hook states after
preflight and document them in contract before implementation. No SDK/endpoint,
save-format or content-slot edits. Reconcile T-0286 metadata to done.

## UX rules
R-UI-1/2 catalog only; R-UI-3 tokens; R-UI-4 locale keys; R-UI-5 no theme edits;
R-UI-6 actual native three-class PL/PSEUDO default/HC130 matrix. Reference
DESIGN.md#settings/#flow-first-launch. Physical locale/device gates remain open.

## Tests
Real valid/invalid manifest discovery, PL-only release filtering, debug transient
EN and restore, initial-locale fallback, failed/unsafe switching with no false
success, per-language progress preservation, lifecycle/native Sheet selection and
layout12-case matrix. Full checks, fresh review and all CI green.
