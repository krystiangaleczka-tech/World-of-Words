# Ceramic UI icons — T-0209

17 official Lucide glyphs from commit `70562c1ee1c4fdcf736fe97bc893fb8511927934`,
the set proposed by the pinned T-0205 art brief. `sources.json` records each URL,
original/installed SHA256 and intended semantic usage. No runtime package is installed.

Only the root stroke changes from `currentColor` to white: Godot imports a transparent
white mask, so later TextureRect/CanvasItem consumers can tint with the relevant Palette
colour via modulate/self_modulate. Geometry remains upstream 24x24, round cap/join and
stroke width 2. Lossless imports use SVG scale 4 (96x96); component dimensions/hit targets
remain governed by Tokens. Disabled/HC colours belong to consumers, not these assets.

`LICENSE.txt` is the exact complete upstream notice, including ISC and Feather-derived
MIT terms. `icon_license.tres` embeds the same notice plus set/source/SPDX metadata so
existing all_resources exports ship it. The later Settings > Licences screen must expose
this Resource's license_notice verbatim, alongside the existing font/engine notices.

This task supplies assets only. Buttons, a11y labels, final styling and screen activation
are subsequent tasks. Postcard/app-icon artwork and T-0205 manual gates remain open.
