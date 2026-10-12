---
id: T-0201
title: Specify the fifteen-level onboarding teaching plan
epic: E11
type: docs
area: docs
risk: med
executor: sol
think: high
ui: med
status: done
depends_on: [T-0200]
touch:
  - docs/GAME_DESIGN.md
  - docs/qa/T-0201-onboarding-plan.md
  - tasks/T-0201-p2-onboarding-plan.md
revision: 1
---

## Goal
Specify the fifteen-level onboarding teaching plan; complete the owner-requested documentation/review work through T-0203.

## Context
Decision0010 is the owner-authorized ordering exception. PRODUCT owns keys/IDs/unlock defaults; GAME_DESIGN owns proposed intents. Original Astra Q1/Q4 requires durable economy/progress ownership before runtime monetization.

## Current state
GAME_DESIGN onboarding section and DESIGN Feature unlock gating specify the canonical PRODUCT timeline; level data remains the existing 65-slot prototype. No detailed T-0201 plan exists.

## Specification
Document per-slot 1..15 teaching goals, required content checks and component/copy-key treatments; preserve canonical unlocks, UMP after1/ATT after6, tutorial hand, once-per-feature inline coach marks and one prompt budget. Daily/streak remain P3; no new first15 content, locales/components or runtime implementation. State proposed Q15 content/UI separation and restart/unlock durability requirements.

## Tests
Verify all15 slots once, key/default timeline matches PRODUCT/DESIGN; no new overlay/components/early monetization/daily; coach copy has keys; consent vs prompt exemptions; cross refs/full checks/fresh review/CI.

## Acceptance
Specified work, bounded touch scope, full make check, fresh independent review and final-head successful12jobCI before sequential squash merge. No human test or legal/SDK evidence fabricated.

## UX rules
DESIGN.md#feature-unlock-gating and #flow-first-launch are the references. Existing components only; no scene changes. R-UI-1: screen tasks may not create components. R-UI-3: use tokens for geometry/motion. R-UI-4: player copy uses translation keys. Reference mockups remain future T-0204/T-0205 work; teaching/copy proposals need the T-0202 second opinion and T-0203 owner disposition.

## Outcome
Specified all15 teaching slots, canonical feature/consent transitions, proposed inline coach copy and prompt/restart/content-language requirements. Current65slot pack, scenes, locales and runtime unchanged. Manual15slot/key/boundary checks pass; fresh independent review APPROVE on f18dd3bd9a35b385ee47756ae76cb44c620c5bde. Full check: 275 GUT /13332 assertions,311 pipeline,370 tools,65 levels. Scope3files/count536 unchanged. Final-head successful12jobCI before merge; final proposal opinion/disposition remains T0202/203.
