---
id: T-0396
title: Audit hard unique-wheel supply ceiling for 10k and 30k campaigns
epic: E22
type: feat
area: pipeline.candidates
risk: medium
executor: sol
think: high
ui: none
status: done
depends_on: [T-0127, T-0131]
touch:
  - pipeline/src/wordgame_pipeline/candidates/campaign_capacity.py
  - pipeline/tests/candidates/test_campaign_capacity.py
  - docs/qa/T-0396-campaign-supply.md
  - tasks/T-0396-campaign-wheel-capacity.md
revision: 1
---

## Goal

Make the 10,000-PL-public-launch requirement measurable without ever claiming
that source-backed wheel supply is production-approved. The long-term target is
30,000 PL slots. The P2 rule in CONTENT.md forbids identical letter multisets
across campaign levels, so source wheel identity gives a strict **theoretical
upper bound**, even before geometry, familiarity and 100-slot word spacing.

## Current state

- WordIndex.tiers maps validated normalized words to level_ok/bonus_ok/banned.
- The shipped P1 content has 65 unchanged levels in game/content/pl/.
- The compact offline content-input receipt includes the exact tier records.
- Existing candidates/coverage.py and the T-0379 shortlist report inspect
  eligible words **per wheel**, but do not establish a campaign-wide maximum.
- T-0395 on separate PR addresses exporter/file naming capacity, not source supply.

## Behavior

1. Add a read-only audit_campaign_capacity(index, existing_wheels, target_slots).
   Count each unique sorted letter multiset whose source has level_ok at most
   once. Never count bonus_ok/banned as seed wheels or manufacture new words.
2. Validate a positive integer target and every shipped wheel's letters
   against the explicit language alphabet and wheel length. Reject duplicate
   shipped multisets and invalid input; do not mutate the source index.
3. Return immutable evidence: source seed wheel count, shipped wheel count,
   source-backed unused signature count, total theoretical unique ceiling and
   a nonnegative target shortfall. Released historical wheels missing from the
   current source remain counted to preserve existing content identity.
4. Compute in time proportional to tier words and shipped wheels, without
   expensive WordIndex.automatic/pools or generation. No external network.
5. Test against the real committed P1 receipt and shipped 65-level pack.
   The test documents current 486 source signatures and launch shortfall 9514;
   it is a pinned snapshot, not a promise of 486 valid playable puzzles.
6. Publish a static, source-identified QA note explaining how expansion and
   owner lexical reviews must precede a 10,000-level release.

## Safety / out of scope

No changes to game/content, no source scraping, no new dependencies, no paid
models/API, no approved classification, no new exported campaign, no loosening
of existing duplicate, frequency, release-lock or grammar constraints. Real
pipeline and Android/iOS QA remain future release gates.

## Acceptance

All exact-head CI green; one-PR task scope; independent reviewer signoff before
merge. Report must never infer that 10,000 levels have been generated.
