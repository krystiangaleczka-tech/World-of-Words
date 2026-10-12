# 0011 — Inter font choice after T-0205 verification

- Status: **accepted by Chris for further work** (2026-10-12); native device verification remains pending.
- Scope: chosen font for documentation references and the later T-0206/T-0208 handoff.
  This task adds no runtime font resources. Supersedes no earlier accepted decision.
- Selected visual direction: Ceramic, owner choice recorded in T-0204 c4c85a4.

## Decision
Use **Inter as one family** for UI, wheel/cells and numbers: weights 400/600/700/800,
fixed default optical size 14, `cv08=1` (uppercase I with serif) and `cv05=1` (lowercase
l with tail). Numeric styles also enable `tnum=1`, with proportional figures disabled.
This avoids a second family and gives I/l/1 distinct shapes in the specimen.
The [author's feature documentation](https://rsms.me/inter/#features) describes those
alternates and tabular figures. Actual shaping of the pinned binary verifies the
I/l alternates at each used weight; visual clarity at device size remains Chris's check.

## Evidence
`docs/design/T-0205/evidence/font-results.json` and `check-font.py` contain repeatable
binary/hash/coverage/feature/weight and HarfBuzz shaping checks. Both font files are
unmodified from Google Fonts commit `bd8f81ddb5c74d5c8897b36ad88b440266245103`.
Exact download URLs and SHA256 hashes are in `docs/design/T-0205/sources.json`.

- Inter covers the required PL/DE characters, punctuation and preview characters;
  variable weights include all used values. Actual GSUB contains `tnum`, `cv08`, `cv05`.
  Tabular advances are equal for 0–9 at weights 400/600/700/800; proportional advances
  differ, confirming that the shaping check distinguishes feature behavior.
- Nunito covers the required characters and weights and has equal default digit
  advances, but the inspected binary lacks an explicit `tnum` feature. Setting it
  does not enable an alternate tabular set. Under DESIGN's explicit tnum verification
  requirement, it is not adopted silently. Keep it as a visual comparison candidate.

The unmodified binaries and complete copyright/OFL notices are bundled only with the
previews. [Inter's pinned OFL notice](https://github.com/google/fonts/blob/bd8f81ddb5c74d5c8897b36ad88b440266245103/ofl/inter/OFL.txt)
and [Nunito's pinned OFL notice](https://github.com/google/fonts/blob/bd8f81ddb5c74d5c8897b36ad88b440266245103/ofl/nunito/OFL.txt)
permit bundling subject to their terms; retain notices and reserved-name conditions.
No project dependency or runtime font resource is added here.

## Handoff
T-0206 records the chosen type values; T-0208 imports unmodified
font assets, includes licences and creates FontVariation resources. Set OpenType
features explicitly there, retain fixed opsz=14 unless separately reviewed, and verify
Godot glyph rendering/tnum and all theme variants. A browser/HarfBuzz PASS is not an
Android/iOS font-import or native a11y PASS. Physical font specimens remain pending.

## Owner disposition
2026-10-12: after seeing the PL/DE comparison specimen and the question whether Inter
should be the font for further work, Chris replied **“Tak — wybieram Inter”**.
This accepts the family and its documented settings for the handoff. It does not certify
physical-device readability, close Q10/Q14, or bypass later task/runtime validation gates.
