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
- Only **two** proposed levels (194 and 199) use a selected word outside
  the seed/partner familiarity shortlist, and have `manual_review_priority: true`.
  **This is not a claim that the other 133 are human-approved**; every
  proposed word still requires lexical/UX review.

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
| 66 | 2 | MOC, SAMO | proposal |
| 67 | 2 | CUMA, RAM | proposal |
| 68 | 2 | MAT, ROTA | proposal |
| 69 | 2 | DNO, TRON | proposal |
| 70 | 2 | OSPA, SAM | proposal |
| 71 | 2 | MAŁO, TAM | proposal |
| 72 | 2 | RUCH, RUS | proposal |
| 73 | 2 | NOC, NORA | proposal |
| 74 | 2 | CYNA, ONA | proposal |
| 75 | 2 | CIEK, ICH | proposal |
| 76 | 2 | TRWA, WAM | proposal |
| 77 | 2 | RATY, TYM | proposal |
| 78 | 2 | KOSZ, SOL | proposal |
| 79 | 2 | JAK, KARK | proposal |
| 80 | 2 | JAR, KRAN | proposal |
| 81 | 2 | KOD, KROK | proposal |
| 82 | 2 | STO, SZŁO | proposal |
| 83 | 2 | PLAC, ŻAL | proposal |
| 84 | 2 | GRA, HART | proposal |
| 85 | 2 | KARO, OGAR | proposal |
| 86 | 2 | GAZ, KOZA | proposal |
| 87 | 2 | DERA, GRAD | proposal |
| 88 | 2 | DAR, DERKA | proposal |
| 89 | 2 | APEL, PAD | proposal |
| 90 | 2 | GRUZ, RAZ | proposal |
| 91 | 3 | PIŁA, RAN | proposal |
| 92 | 3 | AKT, SZAŁ | proposal |
| 93 | 3 | OPAL, RAS | proposal |
| 94 | 3 | ATOL, OPAR | proposal |
| 95 | 3 | LWA, POLAR | proposal |
| 96 | 3 | BAĆ, SZŁA | proposal |
| 97 | 3 | POLA, WAS | proposal |
| 98 | 3 | KAT, KUSZA | proposal |
| 99 | 3 | LAĆ, PORA | proposal |
| 100 | 3 | DAM, HURA | proposal |
| 101 | 3 | DOMY, OKO | proposal |
| 102 | 3 | MODY, ROK | proposal |
| 103 | 3 | BĄK, KURZ | proposal |
| 104 | 3 | ANI, NARTY | proposal |
| 105 | 3 | RAT, SOLA | proposal |
| 106 | 3 | ROLA, URAZ | proposal |
| 107 | 3 | CYK, KNOT | proposal |
| 108 | 3 | BRAT, MAM | proposal |
| 109 | 3 | ROPA, ZŁA | proposal |
| 110 | 3 | KORT, PIK | proposal |
| 111 | 3 | GÓR, IKRA | proposal |
| 112 | 3 | ARKA, KREDA | proposal |
| 113 | 3 | KŁOS, PIŁ | proposal |
| 114 | 3 | PARA, RÓG | proposal |
| 115 | 3 | BAS, SMOŁA | proposal |
| 116 | 3 | RANO, SEN | proposal |
| 117 | 3 | ERA, NOTA | proposal |
| 118 | 3 | KOS, TKWI | proposal |
| 119 | 3 | KIT, SZOK | proposal |
| 120 | 3 | AHA, OWAD | proposal |
| 121 | 3 | MILA, OKA | proposal |
| 122 | 3 | KLAP, LIN | proposal |
| 123 | 3 | KITA, PAL | proposal |
| 124 | 3 | ALT, LUKA, TAKI | proposal |
| 125 | 3 | LAT, WITKA | proposal |
| 126 | 3 | ARIA, DAJ, JAD | proposal |
| 127 | 3 | DAL, DNA, LIANA | proposal |
| 128 | 3 | DAN, MANIA, NAD | proposal |
| 129 | 3 | DAT, RAD, TIARA | proposal |
| 130 | 3 | MAK, ŁAPKI | proposal |
| 131 | 3 | BOK, SZKŁO | proposal |
| 132 | 3 | KAS, PARK, ŁASK | proposal |
| 133 | 3 | DLA, LASKA, SAD | proposal |
| 134 | 3 | APKA, DOK, POD | proposal |
| 135 | 3 | KAPA, UDA | proposal |
| 136 | 3 | DWA, PAKA, WAD | proposal |
| 137 | 3 | LALA, LÓD | proposal |
| 138 | 3 | ONO, PANA | proposal |
| 139 | 3 | ARA, ORNAT | proposal |
| 140 | 3 | TONA, WATA | proposal |
| 141 | 3 | NAS, PRASA, PSA | proposal |
| 142 | 3 | ALE, KANT | proposal |
| 143 | 3 | RANT, RASA | proposal |
| 144 | 3 | RANY, RATA | proposal |
| 145 | 3 | NOTKA, TEKA | proposal |
| 146 | 3 | AKTOR, KRET, RAK | proposal |
| 147 | 3 | TAK, TOTEK | proposal |
| 148 | 3 | MAS, SOK, SŁOMA | proposal |
| 149 | 3 | KOPA, PALA | proposal |
| 150 | 3 | KARA, LAS, SKALA | proposal |
| 151 | 4 | ACH, OCH, TABOR | proposal |
| 152 | 4 | ABY, BAZ, CZAPA | proposal |
| 153 | 4 | KARTA, PAW | proposal |
| 154 | 4 | CAL, NIE, PALCE | proposal |
| 155 | 4 | BAL, BOA, KONAR | proposal |
| 156 | 4 | BAK, CEL, PALEC | proposal |
| 157 | 4 | KARATE, KTO | proposal |
| 158 | 4 | FAN, KAC, PACKA | proposal |
| 159 | 4 | KARETA, PAR | proposal |
| 160 | 4 | MOL, NAM, NORKA | proposal |
| 161 | 4 | NERKI, ORKA | proposal |
| 162 | 4 | KIERAT, TOK | proposal |
| 163 | 4 | AUT, KUR, TYRAN | proposal |
| 164 | 4 | KANTOR, OKAP, PAN | proposal |
| 165 | 4 | KONTRA, OKAZ, ZNA | proposal |
| 166 | 4 | ORKAN, ZŁO, ŁAN | proposal |
| 167 | 4 | GRUSZA, ŻAR | proposal |
| 168 | 4 | MAP, PLAMA, POR | proposal |
| 169 | 4 | BAR, DĄB, RABAT | proposal |
| 170 | 4 | HAU, KAR, MUCHA | proposal |
| 171 | 4 | BEZ, BEZA, ODZEW | proposal |
| 172 | 4 | BAN, BAT, KATAR | proposal |
| 173 | 4 | BOT, KRATA, OBA | proposal |
| 174 | 4 | ARKUSZ, HAK, RUS | proposal |
| 175 | 4 | CEP, KRA, PLACEK | proposal |
| 176 | 5 | CELA, KIER | proposal |
| 177 | 5 | BARY, KASA, RYB | proposal |
| 178 | 5 | BETA, CIEK | proposal |
| 179 | 5 | AKTA, MAT, OSA, SAMO | proposal |
| 180 | 5 | ATAK, MAŁO, TAM | proposal |
| 181 | 5 | NORA, ONA, TAKA | proposal |
| 182 | 5 | KOC, KROK, KUC, RUCH | proposal |
| 183 | 5 | KARK, PLAC | proposal |
| 184 | 5 | KRAN, OSPA, PAS | proposal |
| 185 | 5 | CYNA, GRA, NOC, OGAR | proposal |
| 186 | 5 | KOSZ, ROTA | proposal |
| 187 | 5 | CUD, CUMA, GAD, GRAD | proposal |
| 188 | 5 | BUK, DAR, DBA, DERKA | proposal |
| 189 | 5 | APEL, HAL, HART | proposal |
| 190 | 5 | GRUZ, SZŁO | proposal |
| 191 | 5 | PIŁA, TRWA, TŁA, ŁAP | proposal |
| 192 | 5 | DAŁ, DERA, SZAŁ, ŁAD | proposal |
| 193 | 5 | OPAL, RATY | proposal |
| 194 | 5 | BUS, KOSZA, OBU | proposal · priority review |
| 195 | 5 | OBY, OPAR, POLAR | proposal |
| 196 | 5 | KARO, RAS, SZŁA, ŁZA | proposal |
| 197 | 5 | ATOL, POLA, TRON | proposal |
| 198 | 5 | AKT, BUT, KAT, KUSZA | proposal |
| 199 | 5 | BAŁ, BYK, BYŁ, KOZŁA | proposal · priority review |
| 200 | 5 | HURA, KOZA, RAZ | proposal |
