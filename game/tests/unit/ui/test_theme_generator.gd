extends GutTest

const GENERATOR: GDScript = preload("res://ui/theme/generate_theme.gd")
const SOURCE: GDScript = preload("res://ui/tokens.gd")
const ROLES: Dictionary = {
	"DISPLAY": "Display",
	"TITLE": "Title",
	"SUBTITLE": "Subtitle",
	"BODY": "Body",
	"LABEL": "LabelText",
	"CAPTION": "Caption",
	"NUMERIC": "Numeric",
	"TILE_LETTER": "TileLetter",
	"PREVIEW": "Preview",
}


func test_all_six_saved_themes_match_token_contract() -> void:
	for high_contrast: bool in [false, true]:
		for percent: int in [100, 115, 130]:
			var expected: Theme = GENERATOR.build_theme(high_contrast, percent)
			var file_name: String = (
				"theme_%s_%d.tres" % ["hc" if high_contrast else "default", percent]
			)
			var path: String = "res://ui/theme/generated/" + file_name
			var saved: Theme = (
				ResourceLoader.load(path, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme
			)
			assert_not_null(saved, path)
			if saved == null:
				continue
			_assert_contract(expected, high_contrast, percent)
			_assert_contract(saved, high_contrast, percent)
			assert_eq(saved.resource_name, expected.resource_name)
			assert_is(saved.default_font, FontVariation, "Inter bound by T-0208")


func test_variants_are_independent_and_padding_is_unscaled() -> void:
	var normal: Theme = GENERATOR.build_theme(false, 100)
	var large: Theme = GENERATOR.build_theme(false, 130)
	var hc: Theme = GENERATOR.build_theme(true, 100)
	normal.set_color(&"BG", &"Palette", Color.MAGENTA)
	normal.set_constant(&"M", &"Space", 999)
	assert_eq(large.get_color(&"BG", &"Palette"), Tokens.Palette.BG)
	assert_eq(hc.get_color(&"BG", &"Palette"), Tokens.PaletteHC.BG)
	assert_eq(large.get_constant(&"M", &"Space"), Tokens.Space.M)
	assert_eq(hc.get_constant(&"M", &"Space"), Tokens.Space.M)
	assert_eq(Tokens.Palette.BG, Color("#F6F2E9"))
	assert_gt(large.default_font_size, hc.default_font_size)


func test_css_generation_matches_committed_complete_mirror() -> void:
	var path: String = ProjectSettings.globalize_path("res://../docs/design/tokens.css")
	assert_eq(GENERATOR.css_text(), FileAccess.get_file_as_string(path))
	assert_eq(GENERATOR.css_text(), GENERATOR.css_text(), "Stable repeated generation")


func _assert_contract(theme: Theme, high_contrast: bool, percent: int) -> void:
	var palette: Dictionary = _constants("PaletteHC" if high_contrast else "Palette")
	assert_eq(theme.get_color_list(&"Palette").size(), palette.size())
	for token: String in palette:
		assert_true(theme.has_color(StringName(token), &"Palette"))
		assert_eq(theme.get_color(StringName(token), &"Palette"), palette[token])
	assert_eq(theme.default_font_size, roundi(Tokens.Type.BODY * percent / 100.0))
	var typography: Dictionary = _constants("Type")
	for token: String in ROLES:
		var fixed: bool = token in ["TILE_LETTER", "PREVIEW"]
		var expected_size: int = (
			typography[token] if fixed else roundi(typography[token] * percent / 100.0)
		)
		assert_eq(theme.get_font_size(StringName(token), &"Type"), expected_size)
		var variation: StringName = StringName(ROLES[token])
		assert_eq(theme.get_type_variation_base(variation), &"Label")
		assert_eq(theme.get_font_size(&"font_size", variation), expected_size)
		assert_eq(theme.get_color(&"font_color", variation), palette["TEXT"])
		assert_eq(
			theme.get_constant(StringName(token + "_WEIGHT"), &"Type"),
			typography[token + "_WEIGHT"]
		)
	assert_eq(theme.get_constant(&"CELL_LETTER_RATIO_WEIGHT", &"Type"), 800)
	assert_false(theme.get_font_size_list(&"Type").has("CELL_LETTER_RATIO"))
	for group: String in ["Space", "Radius", "Elevation"]:
		var values: Dictionary = _constants(group)
		for token: String in values:
			if values[token] is int:
				assert_eq(theme.get_constant(StringName(token), StringName(group)), values[token])
			elif values[token] is Color:
				assert_eq(theme.get_color(StringName(token), StringName(group)), values[token])


func _constants(group: String) -> Dictionary:
	var classes: Dictionary = SOURCE.get_script_constant_map()
	return (classes[group] as GDScript).get_script_constant_map()
