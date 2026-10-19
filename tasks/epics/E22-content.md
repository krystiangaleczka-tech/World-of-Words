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
