# T-0152 — Familiarity-led Polish prototype revision

Owner request: Chris, 2026-10-11. Editorial implementation: Codex.
Scope: the existing 65 privately sideloaded, unreleased levels, not a full campaign.

## Feedback and implemented policy

Chris accepts obvious opening answers such as WODA/DWA. He wants unfamiliar
inflections such as RYB and KUR much later, and rates JAR as very difficult despite
its three letters. KOS has an independent bird meaning, but was also explicitly
flagged as a poor early required answer. Validity is not the same as familiarity.

All 65 slots are now pinned through the existing authored YAML mechanism, rather
than allowing the automatic short-wheel/ID order to supply the last 50 puzzles.
No eligible source words have been banned or removed from optional bonus pools.
Required RYB, KUR, LAT and PSI are replaced by familiar full forms; KRA, TOM, BAK,
KIWA, WITA and LUKA are also no longer forced during onboarding. JAR is absent
from the required answers throughout this prototype.

| Slots | Editorial band | Intent/examples |
|---|---|---|
| 1–15 | Very easy | KOT, RAK, DOM/DYM, WODA/DWA, KURA, RYBA, PIES |
| 16–30 | Easy | KAWA, MAPA, OKNO, AUTO, RĘKA, PIŁKA, MAMA/TATA |
| 31–45 | Easy-plus | LAMPA/PALMA/LAMA, MORZE/ZERO, MLEKO/LEK, MOTYL/LOT |
| 46–65 | Medium puzzle complexity | MALINA/LINA/MINA, SERNIK/SER/REKIN, CZAPKA/PACZKA, PARASOL/ROSA/PAS |

These are editorial bands, not player-facing labels or a formal lexical score.
Later puzzles use more letters/intersections while keeping recognizable words.
Breathers with one answer are intentional. Every required form is checked against
the actual pinned native `level_ok` source, and required words remain unique within
the 65 slots, preserving the existing 100-slot spacing policy. Runtime difficulty
remains `0.0` as required for P1; no false P2 classifier has been introduced.

## JAR and KAJ: valid does not mean easy

JAR is a real noun for a steep-sided ravine; the [WSJP PAN entry](https://wsjp.pl/haslo/podglad/10561/jar)
marks it as literary. Chris places it among late/hard vocabulary. This revision
does not ban it globally or assign a fictitious future slot.

Chris also identifies KAJ as a valid archaic/dialectal word. Record it as regional
vocabulary for later editorial review, not as a typo/non-word. However, the pinned
native tiers have no KAJ record. This revision therefore does **not** claim that
the app accepts KAJ as a bonus. A future source-coverage task must obtain auditable
regional lexical evidence and check the proper-name ambiguity before adding it
under the source policy. No source membership was fabricated to satisfy a test.

## Requirements before expansion

Before generating several thousand levels, classify source-backed vocabulary into
multiple familiarity bands (very easy through very hard), considering actual form
frequency, lemma/inflection, dialectal/archaic/literary labels and ambiguity.
Keep this lexical scale distinct from wheel size and grid complexity. Enforce an
early-answer eligibility gate so short obscure forms cannot creep back into the
opening. Treat bonus completeness independently: a hard valid bonus is optional,
not an obstacle to finishing an easy crossword. Define and review this properly
in a separate task; no thousands of levels are generated here.

## Reproduction and verification

Inputs: `pipeline/handmade/pl/opening.yaml`, existing pinned native tiers, unchanged
source/override rules. Content revision increments from 1 to 2, retaining slots
and IDs 1–65. Regenerate with `uv run python -m wordgame_pipeline.p1`, then use
`uv run python -m wordgame_pipeline.p1 --check` for read-only offline reproduction.

Native generation and read-only offline replay both passed. The old ignored local
tier cache predated the committed word overrides; it was regenerated from the
pinned annotation artifact and current overrides before publication. No source
pins or tier rules changed.

- Required answers: 103, all unique; bonus entries across levels: 1,697.
- Final grid: four columns by seven rows; maximum wheel size: seven.
- `make check`: 240 GUT tests, 201 pipeline tests and 142 tools tests passed,
  along with format/lint, import, registries and shipped-content validation.
- Authored-input tampering, generated-pack tampering, complete source bonus pools
  and the opening-word policy are covered by regression tests.
- Exported pack SHA256: `140cf9b545370d3a7cf731eb1fd3344df0e88b6c378bb013e2852227c6282501`.
- Native tier artifact SHA256: `727ee36eb596461c08da6c8bee4926d54f937942e13715208ad9a47cd6a226c9`.

## Android integration and device evidence

The local-only integration branch `t/0152-device-integration` combines content
commit `547f00b` with T-0151's replay fix (`d7b831b`); the content PR remains based
on main and contains no gameplay-code changes. Integrated `make check` passed:
244 GUT tests, 201 pipeline tests, 142 tools tests and all remaining gates.

- Build metadata: T-0152, `Curate the 65 Polish prototype levels by familiarity`,
  `2026-10-11T13:50:19+02:00`. Existing T-0150 interactive metadata helper was used.
- APK: `World of Words-device-build/builds/world-of-words-debug.apk`.
- APK SHA256: `cc1c971a37405bf28bf62744199fcb93be24c98c9cff2c44ea96d4935dbc9776`.
- Existing verifier passed manifest/assets/signature checks and packaged
  boot/audio/debug navigation smoke checks. No signing/settings changes.
- Installed through wireless ADB on Samsung SM_S948B. Diagnostic screen shows
  content version 2 / 65 levels; the final grid shows PARASOL, ROSA and PAS.
- The previous package was already absent at installation preflight (run-as
  reported unknown package; package-removal events exist). No uninstall was
  issued in this task. Restored the known latest T-0151 private save snapshot to
  primary and backup: current slot 66 / highest completed 65. Primary bytes match
  that snapshot before and after device testing. Do not commit private saves.
- Opened slot 7 from diagnostics, shuffled three times, returned to diagnostics
  and reopened. KUR was accepted as a bonus without filling the required grid;
  KURA filled the four-cell grid and completed the level. Saved campaign progress
  stayed byte-identical; no Godot error-level log entries appeared.
- Left slot 1 open for replay testing without resetting campaign progress.

Device screenshots and restore archive are kept outside the repository in the
temporary device-QA directory. This is agent-operated device verification, not
a claim that Chris approved the new difficulty curve. Fresh content review remains
required before merge; Chris's follow-up playtest and FUN GATE remain required
before expansion/release.
