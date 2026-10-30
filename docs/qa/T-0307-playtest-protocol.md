# T-0307 Owner device gameplay QA, slots 1–100

**No playtest performed by this automated preparation.** Results are blank.

Source of rows:
- Slots 1–65: existing `game/content/pl/packs/c-0001-0065.json` prototype.
- Slots 66–100: proposed-only candidate layouts from PR #289. They are
  **not installable levels yet** and must first pass production T-0306.
- The worksheet has exactly **100** rows, with 35 rows not shipped in the game.

For each slot actually played, record device, exact APK/app version, completion
time, mis-swipes, unfamiliar words, geometry/animation problems and verdict.
Play all of 1–100, not a sample. Open a QA flag for every questionable word
or experience; reviewed flags must be resolved into explicit owner decisions
and the pipeline rebuilt from authorized source words.

Quality gates also include 1–15 tutorial flow, protected released geometry,
lack of accidental hints or ads and COMPACT screen readability. A duration
or pass/fail must never be filled from fixture tests or theoretical simulations.

`T-0307` can be done only after a **real 200-level P2 build** from T-0306,
T-0294 debug selectors and Chris's completed review on a device.
