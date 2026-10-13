extends GutTest

const TOKEN_SCRIPT: GDScript = preload("res://ui/tokens.gd")

const GROUPS: Array[String] = [
	"Palette",
	"PaletteHC",
	"Type",
	"Space",
	"Radius",
	"Elevation",
	"Motion",
	"Touch",
	"Reward",
	"Action",
	"Layout",
	"Ease"
]
const RATIOS: Array[String] = [
	"CELL_LETTER_RATIO",
	"CELL_RATIO",
	"TILE_HIT_RATIO",
	"TABLET_MAX_ASPECT",
	"COMPACT_MAX_ASPECT",
	"WHEEL_WIDTH_RATIO",
	"WHEEL_COMPACT_RATIO",
	"GRID_MIN_RATIO",
	"SHEET_MAX_RATIO",
	"WHEEL_RING_RATIO",
	"TILE_RADIUS_RATIO",
	"TILE_SELECTED_SCALE",
	"LANDING_SCALE",
	"WORD_FLASH_SCALE",
	"PREVIEW_VALID_SCALE",
	"BONUS_FLIGHT_SCALE",
	"HINT_START_SCALE",
	"INVALID_CYCLES",
	"HINT_DOT_RATIO",
	"PRESS_SCALE",
	"ALREADY_SCALE",
	"SPREAD_DEGREES",
	"PARTICLE_COUNT"
]


func test_palette_names_match_and_css_mirrors_every_typed_constant() -> void:
	var source: GDScript = TOKEN_SCRIPT
	var classes: Dictionary = source.get_script_constant_map()
	var default_palette: Dictionary = (classes["Palette"] as GDScript).get_script_constant_map()
	var hc_palette: Dictionary = (classes["PaletteHC"] as GDScript).get_script_constant_map()
	assert_eq(default_palette.size(), 19)
	assert_eq(default_palette.keys(), hc_palette.keys())
	var css_path: String = ProjectSettings.globalize_path("res://../docs/design/tokens.css")
	var css: String = FileAccess.get_file_as_string(css_path)
	assert_false(css.is_empty(), "CSS mirror must exist")
	var root: Dictionary = _properties(css.get_slice("}", 0))
	var hc: Dictionary = _properties(css.get_slice("}", 1))
	assert_eq(root.get("--Token-unit"), "calc(1px / 2.6)")
	var count: int = 1
	for group: String in GROUPS:
		var values: Dictionary = (classes[group] as GDScript).get_script_constant_map()
		for token: String in values:
			var key: String = _css_key(group, token)
			assert_true(root.has(key), key)
			assert_eq(root.get(key), _css_value(group, token, values[token]), key)
			count += 1
	assert_eq(root.size(), count, "No fixture helpers or untested mirror properties")
	assert_eq(hc.size(), hc_palette.size())
	for token: String in hc_palette:
		assert_eq(hc.get("--Palette-" + token), "var(--PaletteHC-" + token + ")")


func test_type_weights_and_accepted_geometry() -> void:
	var classes: Dictionary = (TOKEN_SCRIPT).get_script_constant_map()
	var values: Dictionary = (classes["Type"] as GDScript).get_script_constant_map()
	var weights: Dictionary = {
		"DISPLAY": 800,
		"TITLE": 700,
		"SUBTITLE": 700,
		"BODY": 400,
		"LABEL": 600,
		"CAPTION": 600,
		"NUMERIC": 700,
		"TILE_LETTER": 800,
		"PREVIEW": 800,
		"CELL_LETTER_RATIO": 800,
	}
	for token: String in weights:
		assert_eq(values.get(token + "_WEIGHT"), weights[token], token)
	assert_eq(Tokens.Layout.WHEEL_MIN, 450)
	assert_eq(Tokens.Type.CELL_LETTER_RATIO, 0.62)
	assert_eq(Tokens.Radius.CELL_RATIO, 0.18)
	assert_gte(
		(
			Tokens.Layout.WHEEL_MIN
			* Tokens.Layout.TILE_RADIUS_RATIO
			* 2.0
			* Tokens.Touch.TILE_HIT_RATIO
		),
		float(Tokens.Touch.MIN_TARGET)
	)
	assert_eq(Tokens.Elevation.LOW_COLOR, Color("#283E351F"))
	assert_eq(Tokens.Ease.OUT, Vector2i(Tween.TRANS_CUBIC, Tween.EASE_OUT))
	assert_eq(Tokens.Ease.IN, Vector2i(Tween.TRANS_CUBIC, Tween.EASE_IN))
	assert_eq(Tokens.Ease.IN_OUT, Vector2i(Tween.TRANS_SINE, Tween.EASE_IN_OUT))
	assert_eq(Tokens.Ease.SPRING, Vector2i(Tween.TRANS_BACK, Tween.EASE_OUT))


func test_declared_text_background_pairs_have_required_contrast() -> void:
	var classes: Dictionary = (TOKEN_SCRIPT).get_script_constant_map()
	var pairs: Array[Array] = [
		["TEXT", "BG"],
		["TEXT", "SURFACE"],
		["TEXT", "SURFACE_ALT"],
		["TEXT", "TILE"],
		["TEXT", "CELL_EMPTY"],
		["TEXT", "CELL_FILLED"],
		["TEXT", "CELL_HINTED"],
		["TEXT_MUTED", "BG"],
		["TEXT_MUTED", "SURFACE"],
		["TEXT_MUTED", "SURFACE_ALT"],
		["ON_PRIMARY", "PRIMARY"],
		["ON_PRIMARY", "TILE_SELECTED"],
		["PRIMARY", "SURFACE"],
		["SUCCESS", "BG"],
		["ERROR", "BG"],
		["BONUS", "BG"],
		["COIN", "SURFACE"],
	]
	for group: String in ["Palette", "PaletteHC"]:
		var values: Dictionary = (classes[group] as GDScript).get_script_constant_map()
		var floor_ratio: float = 7.0 if group == "PaletteHC" else 4.5
		for pair: Array in pairs:
			assert_gte(_contrast(values[pair[0]], values[pair[1]]), floor_ratio, group + str(pair))


func _properties(block: String) -> Dictionary:
	var pattern: RegEx = RegEx.new()
	pattern.compile("(--[A-Za-z0-9_-]+):\\s*([^;]+);")
	var result: Dictionary = {}
	for match_result: RegExMatch in pattern.search_all(block):
		var key: String = match_result.get_string(1)
		assert_false(result.has(key), "Duplicate property: " + key)
		result[key] = match_result.get_string(2).strip_edges()
	return result


func _css_key(group: String, token: String) -> String:
	if group == "Type":
		if token.ends_with("_WEIGHT"):
			return "--Type-" + token.trim_suffix("_WEIGHT") + "-weight"
		if token != "CELL_LETTER_RATIO":
			return "--Type-" + token + "-size"
	return "--" + group + "-" + token


func _css_value(group: String, token: String, value: Variant) -> String:
	if value is Color:
		var colour: Color = value
		return "#" + colour.to_html(colour.a < 1.0).to_upper()
	if value is Vector2i:
		var easing: Vector2i = value
		return "%d %d" % [easing.x, easing.y]
	if group == "Motion":
		return str(value) + "ms"
	if token in RATIOS or token.ends_with("_WEIGHT"):
		return str(value)
	return "calc(" + str(value) + " * var(--Token-unit))"


func _linear(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


func _luminance(colour: Color) -> float:
	return 0.2126 * _linear(colour.r) + 0.7152 * _linear(colour.g) + 0.0722 * _linear(colour.b)


func _contrast(first: Color, second: Color) -> float:
	var a: float = _luminance(first)
	var b: float = _luminance(second)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
