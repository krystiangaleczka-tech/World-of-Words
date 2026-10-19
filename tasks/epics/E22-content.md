---
id: E22
title: Polish production content
phase: 2
status: active
---

## Goal
Prepare deterministic reviewed production content without changing published slots.

## Bounded offline wave (T-0354..T-0356)
After T-0353, implement T-0298 raw features (T-0354), explicit configured scorer
(T-0355) and T-0299 duplicate/repetition analysis (T-0356) independently of paid AI.
Current P1 schemas, geometry and tier contracts are already merged. These modules
are not activated by P1 stage selection and do not regenerate shipped content.

## Gates
T-0296 production classification still requires private repository/API key/spend
cap and human authorization; no call is inferred. T-0297 suggestion integration,
production weights/calibration, curve/sequence integration, handmade levels1–15,
200-level production build and Chris's lexical/playtest review remain open.
No new content word, travel name/fact or release approval is invented by this wave.

T-0355 adds an immutable explicit range/direction/weight configuration and bounded
weighted score with per-feature explanation/config hash. No default production
weights are supplied. It remains offline/unactivated; T-0356 audits candidate
repetition, while production classification/calibration/sequence gates stay open.

T-0356 closes this bounded offline wave with immutable pair evidence for identical
letter multisets, selected-word Jaccard and campaign crossword/seed repetition.
All crossword words retain the existing100-slot minimum; bonus and incomparable
daily positions cannot change campaign spacing. Explicit policy thresholds and
seed provenance are caller-owned. No candidate selection or content regeneration
is activated; T-0296..T-0307 production/integration/human gates remain open.

T-0357 prepares the independent regional target portion of T-0300: explicit trend,
saw-tooth and landmark/recovery calculations, with onboarding1–15 never assigned
a generated target. Region-local queries allocate no campaign; parameters are
fixtures/caller-owned, not approved production calibration. Slot assignment,
region/location integration, released locks and actual sequence activation remain
open together with the production content/human gates above.

## Protected planning wave (T-0358..T-0360)
T-0358 validates region/location partitions and authored/released identity
reservations; T-0359 selects deterministic candidate assignments against curve and
duplicate constraints; T-0360 composes a readonly preview/report. Onboarding and
landmarks require authored proof; released identity cannot move. Existing export
owns locked geometry; no production parameters, publication or AI call is inferred.

T-0359 assigns free slots by nearest explicit score/ID with all future reservations
already protected. Authored/released candidates stay fixed, duplicate/repetition
policy is checked against future/past, and blocked greedy selection returns no
partial plan. T-0360 still binds real input scores/provenance and reports preview;
production calibration, released geometry proof and publishing remain separate.

T-0359 preserves all fixed future identities while selecting free candidates by
nearest score then ID, with duplicate rejection evidence and no partial result.
T-0360 closes this planning wave with an explicit readonly JSON preview: fresh common-
config scores, source/request hashes and structured success/blocked reports. Supplied
handmade/seed declarations are not approval. Released geometry, tier/bonus/source
approval, seed provenance and production calibration remain explicitly unverified;
lock enforcement is later T-0301/T-0302 work, not an existing implemented export check.
No production content, P1 handler activation, parameter defaults or publication.

## Release geometry wave (T-0361..T-0363)
T-0361 defines strict immutable released-prefix locks and exact geometry hashes;
T-0362 integrates read-only content validation; T-0363 guards export/publication.
No existing prototype is declared released and no baseline is created. Actual
release cutting/lock updates remain later T-0302 work requiring the real release
boundary. Remaining token/difficulty validation and production/human gates stay open.

T-0362 enforces an existing released-prefix lock before content evidence work.
Strict validate-content --require-release-lock rejects absence; default absent-lock
behavior remains pre-release P1. Valid appends and independent repair validation stay
available. T-0363 will guard export/publication; no real release baseline is inferred.

T-0363 closes the protection wave: export verifies locks before returning a stage
payload and publish independently reloads the canonical registry-root lock before
any output/check/no-op/version/staging path. Strict build --require-release-lock
covers normal and --check exports, including custom output. No actual baseline,
release cut/update or production content is created; remaining T-0301/T-0302 and
classification/calibration/human release gates remain open.

## Explicit release tooling wave (T-0364..T-0366)
T-0364 proposes append-only immutable locks without replacing any old hashes;
T-0365 binds a readonly proposal to validated content; T-0366 provides explicit
guarded updates. Tests use temporary baselines only. A real release cut and Chris's
approval remain external actions, along with production/calibration/content gates.

T-0365 binds immutable release proposals to the canonical bundle, exact evidence,
current language/schema context and old semantic lock. Existing readonly validation
runs between snapshots, detecting stale inputs. No evidence/lock preparation or
writes; real release approval and remaining P2 production gates stay external.
