# T-0305 Owner review of handmade onboarding 1–15

**Preparation only. Not an approval or a new 200-level build.**

Existing hand-authored YAML: `pipeline/handmade/pl/opening.yaml`.
Existing rendered prototype levels: `game/content/pl/packs/c-0001-0065.json`.
The first **15** slots already exist as handmade prototypes. Re-authoring them
without review would be unnecessary and would risk changing the established
onboarding experience.

The CSV checks each slot, exact wheel letters, selected answers, bonus count,
and grid dimensions. Owner columns are intentionally empty. On a real Android
build, verify for **each slot**:
- Polish lexical familiarity and suitability of all required crossword words
  (link unresolved decisions to T-0304);
- tutorial progression and the very first swipe;
- expected wheel, no accidental unseen hints, touch handling and readability;
- grid size, letters, connected crossings, bonuses and completion animation;
- no blocking regression on COMPACT phone and reduced-motion mode.

Record a concrete `owner_approval` and notes after real play. If changes are
needed, update the canonical `pipeline/handmade/pl/opening.yaml` in a
separate scoped implementation with source-backed validation, then rebuild
and retest. Do not change published P1 levels while preparing a P2 review.

**T-0305 remains blocked until human sign-off and T-0304.**
