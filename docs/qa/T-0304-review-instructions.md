# T-0304 Polish lexical owner review worksheet

This is **not** owner sign-off. It is an editorial review sheet generated
from the unchanged P1 prototype levels 1–65 and the **proposed-only** slots
66–200 from PR #289. There is no generated release content.

- Total levels represented: **200**.
- Unique selected crossword words requiring editorial eligibility check: **376**.
- Selected words missing a pinned `level_ok` tier in the compact source: **0**.
- Every 66–200 proposal carries `manual_review_priority=true`.
- Source for proposed slots: `pipeline/reviews/pl/T-0306-200-level-candidates.json` (PR #289).
- Source for current prototype slots: `game/content/pl/packs/c-0001-0065.json`.
- Eligibility source: `pipeline/content-inputs/pl.json`. This is **not**
  the full licensed SJP dictionary and not a substitute for human review.
- The lexical-review queue from T-0296 must be rerun against the selected
  words with correct independently pinned source, annotation and override
  bytes before accepting a production decision.

Complete the empty owner columns with manual judgements:
`owner_eligibility_decision` (keep/bonus_only/ban/needs_research),
`owner_familiarity_band` (1–5 where applicable), and
`owner_review_note` (evidence/reason). The automated generator deliberately
does not put words in the mouth of the reviewer.

Review special attention: morphology, context, archaic/inflected forms,
trademark/proper names, adult content, overly obscure forms and
crossword answer recurrence. Only independently approved decisions
may later be transferred into the **canonical**
`pipeline/overrides/pl.csv` and reviewed familiarity catalog.

**T-0304 remains blocked pending a real human decision and T-0297 merge.**
