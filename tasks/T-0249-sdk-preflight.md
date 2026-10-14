---
id: T-0249
title: Prepare analytics and crash SDK integration with provider prerequisites
epic: E17
type: infra
area: infra
risk: high
executor: human
think: med
ui: none
status: blocked
depends_on: [T-0248, T-0208]
touch:
  - docs/qa/T-0249-sdk-preflight.md
  - tasks/T-0249-sdk-preflight.md
  - tasks/T-0248-name-review.md
revision: 1
---

## Goal
Prepare the next roadmap SDK task and establish the provider/configuration prerequisites needed
for actual Firebase Analytics and Sentry installation. This revision is preflight only, not completion.

## Current state
Main4c1a06c contains merged T-0248 and completed T-0208. Platform holds Fake Analytics/Crash adapters;
no Firebase/Sentry SDK is installed. Decision0009 selects godot-x/firebase Analytics and
getsentry/sentry-godot2.x. Decision0007 requires production identity com.mazen.worldofwordgame.
S1 reports record unprepared provider resources and deferred P6/P7. Chris has explicitly confirmed
that the provider projects are not yet created; a managed-environment secret list is not evidence
of GitHub Actions secret readiness.

## Specification
1. Record exact upstream candidate releases, source commits, published asset sizes/digests and
   setup requirements. Distinguish metadata from independently downloaded/verified binaries.
2. List provider configuration inputs and the expected production identifiers without exposing
   values. Ask the owner about project/configuration readiness; do not infer it from silence.
3. Plan Firebase Core+Analytics only, preserving denied collection defaults. Sentry auto-init must
   be disabled until the consent/configuration owner permits initialization. No Messaging or
   Crashlytics activation is introduced. Keep existing Fakes until later adapters are implemented.
4. Actual install/export/CI/plugin/configuration changes require a subsequent revision with explicit
   bounded touch and verified inputs. Do not mark this task done or treat HTTPS fallback as selected.
5. Reconcile already-merged T-0248 status. Preserve all original provider/device/release gates.

## Tests
Task/scope lint; validate candidate metadata against upstream release/tag/source references;
full make check before publishing preparation. Fresh independent review before eventual merge;
actual installation must additionally prove clean import/export, no pre-consent SDK collection,
matching production configs and both Android/iOS integration. P6/P7 remain downstream device evidence.

## Acceptance
Actual SDK acquisition, installation and provider configuration are still required for T-0249
completion; preparation report alone cannot satisfy T-0252/T-0253 or release prerequisites.

## Escalation
S11 / provider configuration: Chris confirmed "Jeszcze nie są utworzone" ("They are not yet created")
for Firebase/Sentry projects. The owner was asked for readiness status only, never credential values. This branch prepares reviewable
requirements; no SDK, project/export settings, permissions, endpoint or credential is changed.
