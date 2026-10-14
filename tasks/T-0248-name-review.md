---
id: T-0248
title: Review irreversible analytics names, IAP IDs and config namespaces
epic: E17
type: docs
area: docs
risk: med
executor: human
think: high
ui: none
status: blocked
depends_on: [T-0247]
touch:
  - docs/qa/T-0248-name-review.md
  - tasks/T-0248-name-review.md
  - tasks/T-0247-analytics-registry-p2.md
revision: 1
---

## Goal
Obtain the roadmap-required independent second opinion before irreversible provider/store names
are released. Chris starts an Opus session; an alternative reviewer needs explicit owner selection.

## Current state
Main e3fe760 contains merged T-0247 (d16fa90): 47 typed event definitions in 11 area files,
35 config definitions in 9 area files, runtime/schema provider-name guards, and PRODUCT's five
versioned IAP IDs. T-0247's file still says review; reconcile its already-merged status only.
No T-0248 opinion or store/provider certification exists. Opus is unavailable in this environment.

## Specification
1. Freeze an auditable inventory with source hashes, event payloads, config namespaces and all five
   PRODUCT IAP IDs. Include P3 inert contracts without claiming activation.
2. Reviewer checks PRODUCT parity, provider reserved-name protections, reporting semantics/units,
   privacy-sensitive payloads, namespace ownership and irreversible IAP naming/versioning.
3. Record the actual reviewer identity, exact source, findings/severity and disposition. Any runtime,
   registry or product-contract remediation requires a separate bounded task; do not rename here.
4. Keep this task blocked until the owner-selected independent opinion is actually received and all
   blockers are resolved. Do not infer selection from silence or treat packet preparation as PASS.
5. Store products, pricing approval, SDK/provider setup, consent certification and physical-device
   gates remain with their original tasks.

## Tests
Validate inventory against repository JSON and PRODUCT; registry checks and analytics Python tests;
full make check, task/scope lint, fresh independent exact-head review and all14CI before merge.

## Acceptance
An actual required independent opinion exists; findings have explicit dispositions; no runtime or
canonical names changed. No fabricated Opus/store/provider evidence.

## Pending reviewer selection
Chris was asked to select an independent GPT substitute for this checkpoint or supply an external
Opus opinion. No answer has been received. The earlier decision0010 substitution is scoped to T-0202.
