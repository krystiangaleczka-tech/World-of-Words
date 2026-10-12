# Ceramic theme foundations — T-0207

Run from the repository root with the pinned Godot 4.7.2 editor binary:

```sh
godot --headless --path game --import --quit
godot --headless --path game --script res://ui/theme/generate_theme_cli.gd
```

In the editor, open generate_theme.gd and use Run in the Script Editor. EditorScript
cannot serve as the CLI MainLoop, so the SceneTree adapter calls the same generator.
Both write six generated/theme_<default|hc>_<100|115|130>.tres resources and replace
docs/design/tokens.css at the repository root from the typed Tokens constants. Do not edit outputs.

These resources are inactive foundations: semantic Palette colours, scaled Type font
sizes, Label type variations, weight metadata and Space/Radius/Elevation metadata.
Only text sizes scale; TILE_LETTER/PREVIEW, geometry ratios and padding do not. Radius.CELL_RATIO also remains a float in Tokens,
not a lossy integer Theme constant. The
geometric cell-letter ratio stays in Tokens; it is not converted to a fixed font size.
Ease pairs in CSS retain their Godot integer metadata; they are not CSS timing functions.

No font resources are bound. Godot fallback fonts do not implement the selected Inter
weights or tnum. T-0208 must import Inter/FontVariation resources and bind them to the
appropriate Type variations before production adoption. Component tasks still own
StyleBox states, HC outlines, focus cues, hit targets and layout. No project default
theme or screen has been changed here.

Review/merge this stacked task after T-0206. It does not close its pending physical-device
acceptance or the original FUN/Opus/Q10/Q14 gates. The generator adds no dependency,
autoload, settings/save state or runtime allocation path.
