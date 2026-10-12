# Ceramic — postcard and icon art direction proposal

Status: proposed for Chris's Q14 review. No production artwork or tool licence is accepted.
The owner selected the Ceramic UI mood in T-0204; this extends it into a repeatable art brief.

## Mood and material
Quiet travel observations: a quay, a garden, a small street, a hillside. Warm paper, matte
paint, soft edges and a restrained green accent. Use clear large shapes with slight painted
variation. Keep generous open sky and one focal feature. No glossy 3D, photographic surface,
shouting saturation, busy lettering, gradients suggesting metallic UI, or recognizable brands.

Use the Ceramic Palette BG/SURFACE/PRIMARY as the visual anchor. Art may add muted clay,
stone and sky hues after review, but never supplies UI status colours. Counters, labels and
touch controls sit on stable surfaces; they do not compete with detailed art.
The geometric SVG postcards in these mockups are original layout placeholders, not evidence
that a final illustration, place identity or licensed source photograph has been approved.

## Postcards
- One illustration per future manifest location; ids/names and facts come from its content
  task. Current names are synthetic previews and are not new production locations.
- Landscape composition 8:5 for the mockup; deliver an uncropped master with focal shapes
  inside a safe central area. Final production pixel dimensions belong to its asset task.
- Four logical pieces (approved starting meta.postcard.pieces=4) are a runtime mask, never
  painted into the art. Avoid putting the sole landmark/detail across every piece boundary.
- Unrevealed pieces use paper with drawn seams, not only tint. Complete state has a stamp
  and text/icon cue. Test 2/4 and 4/4 plus thumbnail/full sizes before acceptance.
- Export static sRGB PNG with no embedded text. Keep a prompt, source/master, file hash,
  tool/model/version/date and edit history. Prefer the same palette and rendering method
  across all locations in a region. Retain rights/source notes for every reference input.
- UI labels remain readable in HC; the art need not become seven-to-one line art, but an
  image never carries status without the accompanying label/shape cue.

## Prompt templates

Postcard: "Original quiet travel illustration for [approved location description]. Warm
matte painted paper, simplified clear shapes, muted Ceramic greens, soft stone and clay,
wide open sky, one calm focal feature, generous negative space, 8:5 landscape composition,
central crop-safe subject. No text, borders, logos or recognizable branded objects. Do not
paint a puzzle-piece grid; the game applies its reveal mask separately."

Region consistency: add the exact approved palette, light direction, texture strength and
reference description from the first accepted postcard. Review thumbnails side by side.
Do not name a living artist or copy a supplied copyrighted composition as a style shortcut.

## App icon
Use one simple original word/puzzle motif, high silhouette clarity and no small text or
reward/ad symbols. Derive colours from the accepted Ceramic palette; evaluate at launcher
size and against light/dark launcher backgrounds. Final store dimensions, platform masking
and original asset export belong to T-0209/T-0308 or an explicit icon task. No icon is installed
or submitted here; the existing prototype W mark is unaffected.

## UI icons
Recommend **Lucide** as one consistent outline set: 24-unit source geometry, currentColor,
consistent stroke, named semantic glyphs rather than font/emoji symbols. This preview bundles
only the required official glyphs and the complete licence at pinned source commit recorded
in sources.json. [Lucide's pinned licence](https://github.com/lucide-icons/lucide/blob/70562c1ee1c4fdcf736fe97bc893fb8511927934/LICENSE)
contains ISC and inherited MIT notices; preserve both in the later production import and
Settings licences. This is a proposal for T-0209, not a game addon or runtime import.

## Q14 tool and approval gate
Chris owns the image-generation tool and commercial-use/licence decision. No provider has
been selected here. Before T-0308, record the chosen tool, applicable terms/date/account scope,
reference rights and approval of a single style sample, then apply the templates consistently.
A style document is not commercial-rights clearance. T-0205 can be reviewed before production
art generation; Q14 adoption and physical screenshot/taste evidence must remain explicit.
