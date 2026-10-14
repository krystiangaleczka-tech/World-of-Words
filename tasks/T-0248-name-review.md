---
id: T-0248
title: Review irreversible analytics names, IAP IDs and config namespaces
epic: E17
type: docs
area: docs
risk: med
executor: sol
think: high
ui: none
status: review
depends_on: [T-0247]
touch:
  - docs/qa/T-0248-name-review.md
  - tasks/T-0248-name-review.md
  - tasks/T-0247-analytics-registry-p2.md
revision: 2
---

## Goal
Review irreversible provider/store names before release. Chris explicitly selected a self-authored
GPT opinion for this checkpoint; retain that provenance and a separate fresh PR-quality review.

## Current state
Main e3fe760 contains merged T-0247 (d16fa90): 47 typed event definitions in 11 area files,
35 config definitions in 9 area files, runtime/schema provider-name guards, and PRODUCT's five
versioned IAP IDs. T-0247's file still says review; reconcile its already-merged status only.
The initial packet a1233df contains no opinion. Opus is unavailable in this environment.
The owner has now requested that the current assistant write the opinion itself.

## Specification
1. Freeze an auditable inventory with source hashes, event payloads, config namespaces and all five
   PRODUCT IAP IDs. Include P3 inert contracts without claiming activation.
2. Reviewer checks PRODUCT parity, provider reserved-name protections, reporting semantics/units,
   privacy-sensitive payloads, namespace ownership and irreversible IAP naming/versioning.
3. Record the actual reviewer identity, exact source, findings/severity and disposition. Any runtime,
   registry or product-contract remediation requires a separate bounded task; do not rename here.
4. Complete the owner-selected self-authored GPT opinion and explicitly label it as neither Opus
   nor an independent second opinion. Preserve actual findings/dispositions; a fresh independent
   PR-quality reviewer still verifies the final report before merge.
5. Store products, pricing approval, SDK/provider setup, consent certification and physical-device
   gates remain with their original tasks.

## Tests
Validate inventory against repository JSON and PRODUCT; registry checks and analytics Python tests;
full make check, task/scope lint, fresh independent exact-head review and all14CI before merge.

## Acceptance
The owner-selected GPT opinion exists, findings have explicit dispositions, and a fresh independent
PR-quality review passes. No runtime/canonical names changed or Opus/store/provider evidence fabricated.

## Owner disposition

After the packet PR175 and explanation of the unavailable Opus gate, Chris instructed
"Zrób samemu opinie" ("Write the opinion yourself"). This explicitly selects the current GPT
assistant and waives Opus and independence of the primary opinion for T-0248 only. It does not
waive the fresh independent PR review or other human/store/provider/release gates. ROADMAP remains
unchanged; this bounded exception and reviewer identity are recorded in the report and PR.

## Outcome

Self-authored Codex/GPT opinion: PASS for the current names, no rename blocker. Five nonblocking
integration findings have named downstream dispositions. The ordinary fresh PR-quality review
remains required; it must not be relabeled as an independent Opus opinion.
