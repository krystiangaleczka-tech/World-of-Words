# T-0131 — first Polish campaign

The generated campaign contains 65 slots: 15 authored opening boards and 50
automatic boards. Native registered candidates → grid → validate → export stages
run against the current full Polish tier artifact. The P1 plan selects candidates
whose entire eligible answer pool was kept in T-0129's review or authored in
T-0130. It preserves all source-backed bonus forms and never promotes tiers.

Reproduce locally after generating native tiers:

```sh
uv run python -m wordgame_pipeline.p1
uv run python -m wordgame_pipeline.p1 --check
make check GODOT=/tmp/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
```

The generated compact input receipt contains every eligible form for all retained
candidate and handmade wheels, including candidates not shipped. Offline CI
reruns unchanged seeded grid search, semantic validation and export, and checks
exact manifest/pack bytes. It verifies current source pins, language config,
review, overrides, handmade inputs, selection plan and schema hashes. Tests run
without native artifacts, verify read-only behavior and reject even a semantically
valid pack edit with repaired manifest/evidence hashes.

CI trusts the committed native tier extract: it does not redownload or reannotate
the full dictionary to prove a forged receipt's membership. Native extraction,
recorded full-tier hash and independent content review are the source boundary.
The original source licenses and hashes are in root NOTICE; the builder copies
it byte-for-byte to game/content/NOTICE and replay verifies that copy.

Handmade wheels progress from 3 to 5 tiles. The initial reviewed automatic pool
produces 50 three-tile boards, ordered by the unchanged exporter. This is an
internal P1 campaign, with difficulty 0.0 and no landmarks or P2 scoring/curve.
It does not claim a final production progression. Human playtest and word/level
feedback remain T-0140; no Chris device test is claimed.

The existing GUT content bot loads every shipped slot, forms each required and
bonus word using distinct tiles, fills all grid cells without hints, checks one
completion event and verifies that repeated answers do not change progress.

Native build evidence: 179 retained automatic candidates; 93 unique required words; 201 bonus entries across all 65 boards.

- pipeline/build/pl/05-tiers/artifact.json: `727ee36eb596461c08da6c8bee4926d54f937942e13715208ad9a47cd6a226c9`
- game/content/pl/manifest.json: `97a87a620d59485243f42542f742113d4d0d835d8e7124ca5c2a431e5272c6ea`
- game/content/pl/packs/c-0001-0065.json: `2cf40aef7e28d01c1d6790c0c76b6ec6703216751788f4f92af4b8691b560aab`

Compact receipt: 426 eligible tier records for all 179 automatic inputs and 15 authored wheels. Native build and offline replay pass. Full make check passes 199 GUT tests (8,010 assertions, including all 65 shipped boards), 199 pipeline tests and 81 tools tests. Content validation reports all 65 slots; independent review and remote CI are merge gates.

Fresh independent review APPROVE at 283e7cdf6125476dc0fcb716b8022832163f8b30. Reviewer independently matched all 179 candidates/426 extract records to full native tiers, stage predecessor hashes and replay bytes, and validated all 65 levels against the full source. Remote CI remains the merge gate.
