# T-0306 — Polish 200-slot candidate selection (editorial draft)

Date: 2026-10-29. **Status: proposed / blocked for production.**

## Grounded inventory

- Existing committed P1 campaign: **65 levels**, 1–65. No `game/content/` files altered.
- New candidate arrangements: **135 levels**, contiguous slots 66–200.
- Total target inventory: **200**; only the original 65 are presently shipped.
- New proposed selected crossword answers: **331 placements**; every selected
  word has `level_ok` tier in the pinned `pipeline/content-inputs/pl.json`.
- Each new proposed grid has **at least two** crossword words. Grid and letters
  are explicit inputs, to be checked through the repository's native `make_level`,
  `WordIndex`, and full geometry constraints before accepting this PR.
- New wheel size: five letters for 66–90, six for 91–150,
  seven for 151–200. These are **editorial bands**, not a calibrated
  difficulty measurement; no fake score is written to gameplay packs.
- Unique letter multisets across 200 planned slots and 100-slot spacing
  between selected crossword words are asserted by new tests.
- **All 135 proposed levels require owner lexical/UX review**:
  `manual_review_priority: true` means **pending**, not approved.
  The compact tier extract is a dictionary/heuristic eligibility input and
  T-0129's `reviewed_by=codex` is not human sign-off.
- Comparing the 331 crossword-word placements against the T-0129 catalog
  gives 283 distinct selected words, of which **161 do not have an earlier
  `level_ok` decision in that catalog**. Even the other 122 need
  confirmation for this campaign. There is no owner-approved 200-level batch.
- The former two-item flag (slots 194 and 199) reflected only an internal
  seed/partner shortlist, not actual human review. That unsafe inference
  was removed in the next revision.

## Difficulty and coverage summary

| Slots | Provisional band | Wheel letters | New levels | Crossword answer placements | Source-derived bonus candidates |
|---|---:|---:|---:|---:|---:|
| 1–30 | 1 — tutorial/easy | existing | 30 | existing | existing |
| 31–65 | 2 — easy | existing | 35 | existing | existing |
| 66–90 | 2 — medium transition | 5 | 25 | 50 | 313 |
| 91–120 | 3 — medium | 6 | 30 | 60 | 728 |
| 121–150 | 3 — medium-plus | 6 | 30 | 73 | 877 |
| 151–175 | 4 — hard candidate | 7 | 25 | 69 | 1843 |
| 176–200 | 5 — harder candidate | 7 | 25 | 79 | 1307 |

The large number of source-formable bonus candidates is a **QA warning**.
They must be reviewed for clarity, sensitivity and expected player behavior.
The compact source is not a complete production dictionary, and a high number
of bonus candidates is not itself a sign of a good level.

## Example proposed levels

| Slot | Wheel | Crossword words | Band |
|---:|---|---|---:|
| 66 | ACMOS | MOC, SAMO | 2 |
| 75 | CEHIK | CIEK, ICH | 2 |
| 90 | AGRUZ | GRUZ, RAZ | 2 |
| 100 | ADHMRU | DAM, HURA | 3 |
| 120 | AADHOW | AHA, OWAD | 3 |
| 140 | AANOTW | TONA, WATA | 3 |
| 155 | ABKLNOR | BAL, BOA, KONAR | 4 |
| 175 | ACEKLPR | CEP, KRA, PLACEK | 4 |
| 180 | AAKMOTŁ | ATAK, MAŁO, TAM | 5 |
| 190 | GORSUZŁ | GRUZ, SZŁO | 5 |
| 200 | AHKORUZ | HURA, KOZA, RAZ | 5 |

Every row in the complete 135-slot data file includes wheel letters,
selected answer words, exact crossword grid placements, editorial band,
review status and priority flag.

## Source provenance and zero-cost constraints

The candidate JSON pins the exact Git blob identity for:
`pipeline/content-inputs/pl.json`, the existing
`game/content/pl/packs/c-0001-0065.json`, and
`pipeline/reviews/pl/T-0129-words.csv`. The checker rejects changes
to these files without rebuilding/reviewing the candidate batch.

No API key, LLM batch, network inference, paid classifier, new source
word or player progression change is introduced. All placements are
authoring proposals, not hand-edits to generated game JSON.

## Mandatory gates before this can be called T-0306 done

1. Pass exact-head CI and independent content/technical review.
2. Complete the still-missing production stages T-0297–T-0303 and
   owner-reviewed onboarding T-0305, with approved difficulty weights.
3. Rebuild all 200 through the actual P2 generator, source QA and
   manifest v1.1 region/location metadata; never manually edit packs.
4. Have Chris review source words and bonus lists, then play the first
   ~100 levels and all key difficulty transitions. Fix awkward puzzles.
5. Conduct mobile UI/geometry testing; confirm all generated grids fit
   the COMPACT layout and reward/coach flow on actual devices.

**The PR is preparatory; not merged to production, not a completed 200-level
campaign and not certification of calibrated difficulty.**

## Full 200-slot crossword-answer list (editorial checklist)

Original slots 1–65 are copied here **as reference only**, without changing their
source pack. Slots 66–200 are **proposed**, not playtested or released.

| Slot | Band | Crossword answers | Status |
|---:|---:|---|---|
| 1 | 1 | KOT | shipped P1 |
| 2 | 1 | RAK | shipped P1 |
| 3 | 1 | DOM, DYM | shipped P1 |
| 4 | 1 | LATO | shipped P1 |
| 5 | 1 | KOSA, OSA | shipped P1 |
| 6 | 1 | DWA, WODA | shipped P1 |
| 7 | 1 | KURA | shipped P1 |
| 8 | 1 | RYBA | shipped P1 |
| 9 | 1 | MOST | shipped P1 |
| 10 | 1 | PIES | shipped P1 |
| 11 | 1 | KWIAT | shipped P1 |
| 12 | 1 | KLASA, LAS, SALA | shipped P1 |
| 13 | 1 | ŻABA, ŻABKA | shipped P1 |
| 14 | 1 | KULA, KULKA | shipped P1 |
| 15 | 1 | BAR, TOR, TORBA | shipped P1 |
| 16 | 1 | KAWA | shipped P1 |
| 17 | 1 | MAPA | shipped P1 |
| 18 | 1 | NOGA | shipped P1 |
| 19 | 1 | RĘKA | shipped P1 |
| 20 | 1 | OKNO | shipped P1 |
| 21 | 1 | AUTO | shipped P1 |
| 22 | 1 | PTAK | shipped P1 |
| 23 | 1 | OWOC | shipped P1 |
| 24 | 1 | UCHO | shipped P1 |
| 25 | 1 | GÓRA | shipped P1 |
| 26 | 1 | PIŁKA | shipped P1 |
| 27 | 1 | LALKA | shipped P1 |
| 28 | 1 | RZEKA | shipped P1 |
| 29 | 1 | MAMA | shipped P1 |
| 30 | 1 | TATA | shipped P1 |
| 31 | 2 | LAMA, LAMPA, PALMA | shipped P1 |
| 32 | 2 | DROGA, GAD | shipped P1 |
| 33 | 2 | TRAWA, WARTA | shipped P1 |
| 34 | 2 | MORZE, ZERO | shipped P1 |
| 35 | 2 | ZEBRA | shipped P1 |
| 36 | 2 | BANAN | shipped P1 |
| 37 | 2 | DYNIA | shipped P1 |
| 38 | 2 | KOC, KOCYK | shipped P1 |
| 39 | 2 | LEP, SKLEP | shipped P1 |
| 40 | 2 | LEK, MLEKO | shipped P1 |
| 41 | 2 | MASŁO | shipped P1 |
| 42 | 2 | CHLEB, ECH | shipped P1 |
| 43 | 2 | LOT, MOTYL | shipped P1 |
| 44 | 2 | KOTLET | shipped P1 |
| 45 | 2 | ROWER | shipped P1 |
| 46 | 2 | SZKOŁA | shipped P1 |
| 47 | 2 | RAFA, ŻYRAFA | shipped P1 |
| 48 | 2 | LINA, MALINA, MINA | shipped P1 |
| 49 | 2 | REKIN, SER, SERNIK | shipped P1 |
| 50 | 2 | DESZCZ | shipped P1 |
| 51 | 2 | CHMURA, MUR | shipped P1 |
| 52 | 2 | DRZEWO | shipped P1 |
| 53 | 2 | SŁOŃCE | shipped P1 |
| 54 | 2 | CYTRYNA | shipped P1 |
| 55 | 2 | CUKIER | shipped P1 |
| 56 | 2 | BAT, HERB, HERBATA | shipped P1 |
| 57 | 2 | KARTON, TON | shipped P1 |
| 58 | 2 | PLECAK | shipped P1 |
| 59 | 2 | CZAPKA, PACZKA | shipped P1 |
| 60 | 2 | KADR, KREDKA | shipped P1 |
| 61 | 2 | KARP, KORA, KROPKA | shipped P1 |
| 62 | 2 | GRUSZKA, KURS | shipped P1 |
| 63 | 2 | RAKIETA, TARKA | shipped P1 |
| 64 | 2 | KANAPA, KANAPKA, PAN | shipped P1 |
| 65 | 2 | PARASOL, PAS, ROSA | shipped P1 |
| 66 | 2 | MOC, SAMO | proposal · owner review required |
| 67 | 2 | CUMA, RAM | proposal · owner review required |
| 68 | 2 | MAT, ROTA | proposal · owner review required |
| 69 | 2 | DNO, TRON | proposal · owner review required |
| 70 | 2 | OSPA, SAM | proposal · owner review required |
| 71 | 2 | MAŁO, TAM | proposal · owner review required |
| 72 | 2 | RUCH, RUS | proposal · owner review required |
| 73 | 2 | NOC, NORA | proposal · owner review required |
| 74 | 2 | CYNA, ONA | proposal · owner review required |
| 75 | 2 | CIEK, ICH | proposal · owner review required |
| 76 | 2 | TRWA, WAM | proposal · owner review required |
| 77 | 2 | RATY, TYM | proposal · owner review required |
| 78 | 2 | KOSZ, SOL | proposal · owner review required |
| 79 | 2 | JAK, KARK | proposal · owner review required |
| 80 | 2 | JAR, KRAN | proposal · owner review required |
| 81 | 2 | KOD, KROK | proposal · owner review required |
| 82 | 2 | STO, SZŁO | proposal · owner review required |
| 83 | 2 | PLAC, ŻAL | proposal · owner review required |
| 84 | 2 | GRA, HART | proposal · owner review required |
| 85 | 2 | KARO, OGAR | proposal · owner review required |
| 86 | 2 | GAZ, KOZA | proposal · owner review required |
| 87 | 2 | DERA, GRAD | proposal · owner review required |
| 88 | 2 | DAR, DERKA | proposal · owner review required |
| 89 | 2 | APEL, PAD | proposal · owner review required |
| 90 | 2 | GRUZ, RAZ | proposal · owner review required |
| 91 | 3 | PIŁA, RAN | proposal · owner review required |
| 92 | 3 | AKT, SZAŁ | proposal · owner review required |
| 93 | 3 | OPAL, RAS | proposal · owner review required |
| 94 | 3 | ATOL, OPAR | proposal · owner review required |
| 95 | 3 | LWA, POLAR | proposal · owner review required |
| 96 | 3 | BAĆ, SZŁA | proposal · owner review required |
| 97 | 3 | POLA, WAS | proposal · owner review required |
| 98 | 3 | KAT, KUSZA | proposal · owner review required |
| 99 | 3 | LAĆ, PORA | proposal · owner review required |
| 100 | 3 | DAM, HURA | proposal · owner review required |
| 101 | 3 | DOMY, OKO | proposal · owner review required |
| 102 | 3 | MODY, ROK | proposal · owner review required |
| 103 | 3 | BĄK, KURZ | proposal · owner review required |
| 104 | 3 | ANI, NARTY | proposal · owner review required |
| 105 | 3 | RAT, SOLA | proposal · owner review required |
| 106 | 3 | ROLA, URAZ | proposal · owner review required |
| 107 | 3 | CYK, KNOT | proposal · owner review required |
| 108 | 3 | BRAT, MAM | proposal · owner review required |
| 109 | 3 | ROPA, ZŁA | proposal · owner review required |
| 110 | 3 | KORT, PIK | proposal · owner review required |
| 111 | 3 | GÓR, IKRA | proposal · owner review required |
| 112 | 3 | ARKA, KREDA | proposal · owner review required |
| 113 | 3 | KŁOS, PIŁ | proposal · owner review required |
| 114 | 3 | PARA, RÓG | proposal · owner review required |
| 115 | 3 | BAS, SMOŁA | proposal · owner review required |
| 116 | 3 | RANO, SEN | proposal · owner review required |
| 117 | 3 | ERA, NOTA | proposal · owner review required |
| 118 | 3 | KOS, TKWI | proposal · owner review required |
| 119 | 3 | KIT, SZOK | proposal · owner review required |
| 120 | 3 | AHA, OWAD | proposal · owner review required |
| 121 | 3 | MILA, OKA | proposal · owner review required |
| 122 | 3 | KLAP, LIN | proposal · owner review required |
| 123 | 3 | KITA, PAL | proposal · owner review required |
| 124 | 3 | ALT, LUKA, TAKI | proposal · owner review required |
| 125 | 3 | LAT, WITKA | proposal · owner review required |
| 126 | 3 | ARIA, DAJ, JAD | proposal · owner review required |
| 127 | 3 | DAL, DNA, LIANA | proposal · owner review required |
| 128 | 3 | DAN, MANIA, NAD | proposal · owner review required |
| 129 | 3 | DAT, RAD, TIARA | proposal · owner review required |
| 130 | 3 | MAK, ŁAPKI | proposal · owner review required |
| 131 | 3 | BOK, SZKŁO | proposal · owner review required |
| 132 | 3 | KAS, PARK, ŁASK | proposal · owner review required |
| 133 | 3 | DLA, LASKA, SAD | proposal · owner review required |
| 134 | 3 | APKA, DOK, POD | proposal · owner review required |
| 135 | 3 | KAPA, UDA | proposal · owner review required |
| 136 | 3 | DWA, PAKA, WAD | proposal · owner review required |
| 137 | 3 | LALA, LÓD | proposal · owner review required |
| 138 | 3 | ONO, PANA | proposal · owner review required |
| 139 | 3 | ARA, ORNAT | proposal · owner review required |
| 140 | 3 | TONA, WATA | proposal · owner review required |
| 141 | 3 | NAS, PRASA, PSA | proposal · owner review required |
| 142 | 3 | ALE, KANT | proposal · owner review required |
| 143 | 3 | RANT, RASA | proposal · owner review required |
| 144 | 3 | RANY, RATA | proposal · owner review required |
| 145 | 3 | NOTKA, TEKA | proposal · owner review required |
| 146 | 3 | AKTOR, KRET, RAK | proposal · owner review required |
| 147 | 3 | TAK, TOTEK | proposal · owner review required |
| 148 | 3 | MAS, SOK, SŁOMA | proposal · owner review required |
| 149 | 3 | KOPA, PALA | proposal · owner review required |
| 150 | 3 | KARA, LAS, SKALA | proposal · owner review required |
| 151 | 4 | ACH, OCH, TABOR | proposal · owner review required |
| 152 | 4 | ABY, BAZ, CZAPA | proposal · owner review required |
| 153 | 4 | KARTA, PAW | proposal · owner review required |
| 154 | 4 | CAL, NIE, PALCE | proposal · owner review required |
| 155 | 4 | BAL, BOA, KONAR | proposal · owner review required |
| 156 | 4 | BAK, CEL, PALEC | proposal · owner review required |
| 157 | 4 | KARATE, KTO | proposal · owner review required |
| 158 | 4 | FAN, KAC, PACKA | proposal · owner review required |
| 159 | 4 | KARETA, PAR | proposal · owner review required |
| 160 | 4 | MOL, NAM, NORKA | proposal · owner review required |
| 161 | 4 | NERKI, ORKA | proposal · owner review required |
| 162 | 4 | KIERAT, TOK | proposal · owner review required |
| 163 | 4 | AUT, KUR, TYRAN | proposal · owner review required |
| 164 | 4 | KANTOR, OKAP, PAN | proposal · owner review required |
| 165 | 4 | KONTRA, OKAZ, ZNA | proposal · owner review required |
| 166 | 4 | ORKAN, ZŁO, ŁAN | proposal · owner review required |
| 167 | 4 | GRUSZA, ŻAR | proposal · owner review required |
| 168 | 4 | MAP, PLAMA, POR | proposal · owner review required |
| 169 | 4 | BAR, DĄB, RABAT | proposal · owner review required |
| 170 | 4 | HAU, KAR, MUCHA | proposal · owner review required |
| 171 | 4 | BEZ, BEZA, ODZEW | proposal · owner review required |
| 172 | 4 | BAN, BAT, KATAR | proposal · owner review required |
| 173 | 4 | BOT, KRATA, OBA | proposal · owner review required |
| 174 | 4 | ARKUSZ, HAK, RUS | proposal · owner review required |
| 175 | 4 | CEP, KRA, PLACEK | proposal · owner review required |
| 176 | 5 | CELA, KIER | proposal · owner review required |
| 177 | 5 | BARY, KASA, RYB | proposal · owner review required |
| 178 | 5 | BETA, CIEK | proposal · owner review required |
| 179 | 5 | AKTA, MAT, OSA, SAMO | proposal · owner review required |
| 180 | 5 | ATAK, MAŁO, TAM | proposal · owner review required |
| 181 | 5 | NORA, ONA, TAKA | proposal · owner review required |
| 182 | 5 | KOC, KROK, KUC, RUCH | proposal · owner review required |
| 183 | 5 | KARK, PLAC | proposal · owner review required |
| 184 | 5 | KRAN, OSPA, PAS | proposal · owner review required |
| 185 | 5 | CYNA, GRA, NOC, OGAR | proposal · owner review required |
| 186 | 5 | KOSZ, ROTA | proposal · owner review required |
| 187 | 5 | CUD, CUMA, GAD, GRAD | proposal · owner review required |
| 188 | 5 | BUK, DAR, DBA, DERKA | proposal · owner review required |
| 189 | 5 | APEL, HAL, HART | proposal · owner review required |
| 190 | 5 | GRUZ, SZŁO | proposal · owner review required |
| 191 | 5 | PIŁA, TRWA, TŁA, ŁAP | proposal · owner review required |
| 192 | 5 | DAŁ, DERA, SZAŁ, ŁAD | proposal · owner review required |
| 193 | 5 | OPAL, RATY | proposal · owner review required |
| 194 | 5 | BUS, KOSZA, OBU | proposal · owner review required |
| 195 | 5 | OBY, OPAR, POLAR | proposal · owner review required |
| 196 | 5 | KARO, RAS, SZŁA, ŁZA | proposal · owner review required |
| 197 | 5 | ATOL, POLA, TRON | proposal · owner review required |
| 198 | 5 | AKT, BUT, KAT, KUSZA | proposal · owner review required |
| 199 | 5 | BAŁ, BYK, BYŁ, KOZŁA | proposal · owner review required |
| 200 | 5 | HURA, KOZA, RAZ | proposal · owner review required |
