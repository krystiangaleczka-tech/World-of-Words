@tool
class_name CeramicThemeGenerator
extends EditorScript
## @api Rebuild Ceramic themes, pinned Inter variations and CSS from Tokens.

const OPTICAL_SIZE: int = 14
const FONT_NAMES: Dictionary = {
	Tokens.Type.BODY_WEIGHT: "regular",
	Tokens.Type.LABEL_WEIGHT: "semibold",
	Tokens.Type.TITLE_WEIGHT: "bold",
	Tokens.Type.TILE_LETTER_WEIGHT: "extrabold",
}
const TOKEN_SOURCE: GDScript = preload("res://ui/tokens.gd")
const PERCENTS: Array[int] = [100, 115, 130]
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
	"HINT_DOT_RATIO",
	"PRESS_SCALE",
	"ALREADY_SCALE",
	"SPREAD_DEGREES",
	"PARTICLE_COUNT"
]
const VARIATIONS: Dictionary = {
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


func _run() -> void:
	var result: Error = generate()
	if result != OK:
		push_error("Theme generation failed: %s" % error_string(result))


static func constants(group: String) -> Dictionary:
	var classes: Dictionary = TOKEN_SOURCE.get_script_constant_map()
	return (classes[group] as GDScript).get_script_constant_map()


static func build_theme(high_contrast: bool, text_percent: int) -> Theme:
	assert(text_percent in PERCENTS)
	var theme: Theme = Theme.new()
	theme.resource_name = "Ceramic_%s_%d" % ["hc" if high_contrast else "default", text_percent]
	theme.default_font = _font_resource(Tokens.Type.BODY_WEIGHT)
	theme.set_font(&"font", &"Label", theme.default_font)
	theme.set_font(&"font", &"Button", _font_resource(Tokens.Type.LABEL_WEIGHT))
	theme.default_font_size = roundi(Tokens.Type.BODY * text_percent / 100.0)
	var palette: Dictionary = constants("PaletteHC" if high_contrast else "Palette")
	for token: String in palette:
		theme.set_color(StringName(token), &"Palette", palette[token])
	var typography: Dictionary = constants("Type")
	for token: String in typography:
		if token.ends_with("_WEIGHT"):
			theme.set_constant(StringName(token), &"Type", typography[token])
	for token: String in VARIATIONS:
		var fixed: bool = token in ["TILE_LETTER", "PREVIEW"]
		var size: int = (
			typography[token] if fixed else roundi(typography[token] * text_percent / 100.0)
		)
		theme.set_font_size(StringName(token), &"Type", size)
		var variation: StringName = StringName(VARIATIONS[token])
		theme.set_type_variation(variation, &"Label")
		var font: FontVariation = _font_resource(typography[token + "_WEIGHT"], token == "NUMERIC")
		theme.set_font(StringName(token), &"Type", font)
		theme.set_font(&"font", variation, font)
		theme.set_font_size(&"font_size", variation, size)
		theme.set_color(&"font_color", variation, palette["TEXT"])
	theme.set_font_size(&"font_size", &"Label", theme.default_font_size)
	theme.set_color(&"font_color", &"Label", palette["TEXT"])
	for group: String in ["Space", "Radius", "Elevation"]:
		var values: Dictionary = constants(group)
		for token: String in values:
			if values[token] is Color:
				theme.set_color(StringName(token), StringName(group), values[token])
			elif values[token] is int:
				theme.set_constant(StringName(token), StringName(group), values[token])
	return theme


static func _font_resource(weight: int, numeric: bool = false) -> FontVariation:
	var name: String = "numeric" if numeric else str(FONT_NAMES[weight])
	return load("res://assets/fonts/inter_%s.tres" % name) as FontVariation


static func _generate_fonts() -> Error:
	# Project themes load before first import: use an import-independent generated FontFile.
	var data_font: FontFile = FontFile.new()
	data_font.data = FileAccess.get_file_as_bytes("res://assets/fonts/Inter.ttf")
	var base_path: String = "res://assets/fonts/Inter.res"
	var base_error: Error = ResourceSaver.save(data_font, base_path, ResourceSaver.FLAG_COMPRESS)
	if base_error != OK:
		return base_error
	var base_font: FontFile = (
		ResourceLoader.load(base_path, "FontFile", ResourceLoader.CACHE_MODE_IGNORE) as FontFile
	)
	var notice: Resource = Resource.new()
	notice.set_meta(&"ofl_notice", FileAccess.get_file_as_string("res://assets/fonts/OFL.txt"))
	var notice_error: Error = ResourceSaver.save(notice, "res://assets/fonts/font_license.tres")
	if notice_error != OK:
		return notice_error
	var server: TextServer = TextServerManager.get_primary_interface()
	for name: String in ["regular", "semibold", "bold", "extrabold", "numeric"]:
		var font: FontVariation = FontVariation.new()
		font.base_font = base_font
		var weight: int = (
			Tokens.Type.NUMERIC_WEIGHT if name == "numeric" else int(FONT_NAMES.find_key(name))
		)
		font.variation_opentype = {
			server.name_to_tag("wght"): weight,
			server.name_to_tag("opsz"): OPTICAL_SIZE,
		}
		var features: Dictionary = {
			server.name_to_tag("cv08"): 1,
			server.name_to_tag("cv05"): 1,
		}
		if name == "numeric":
			features[server.name_to_tag("tnum")] = 1
			features[server.name_to_tag("pnum")] = 0
		font.opentype_features = features
		var font_path: String = "res://assets/fonts/inter_%s.tres" % name
		base_font.set_id_for_path(font_path, "1_inter")
		var error: Error = ResourceSaver.save(font, font_path)
		if error != OK:
			return error
	return OK


static func css_text() -> String:
	var lines: PackedStringArray = [
		"/* Generated by T-0207 from game/ui/tokens.gd. Design px / 2.6. */",
		":root {",
		"  --Token-unit: calc(1px / 2.6);"
	]
	for group: String in GROUPS:
		var values: Dictionary = constants(group)
		var names: PackedStringArray = PackedStringArray(values.keys())
		names.sort()
		for token: String in names:
			var key: String = "--" + group + "-" + token
			if group == "Type" and token.ends_with("_WEIGHT"):
				key = "--Type-" + token.trim_suffix("_WEIGHT") + "-weight"
			elif group == "Type" and token != "CELL_LETTER_RATIO":
				key += "-size"
			lines.append("  %s: %s;" % [key, _css_value(group, token, values[token])])
	lines.append("}")
	lines.append('[data-hc="true"] {')
	var names: PackedStringArray = PackedStringArray(constants("PaletteHC").keys())
	names.sort()
	for token: String in names:
		lines.append("  --Palette-%s: var(--PaletteHC-%s);" % [token, token])
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _css_value(group: String, token: String, value: Variant) -> String:
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


static func generate(
	theme_dir: String = "res://ui/theme/generated",
	css_path: String = "res://../docs/design/tokens.css"
) -> Error:
	var result: Error = _generate_fonts()
	if result != OK:
		return result
	result = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(theme_dir))
	if result != OK:
		return result
	for high_contrast: bool in [false, true]:
		for percent: int in PERCENTS:
			var name: String = "theme_%s_%d.tres" % ["hc" if high_contrast else "default", percent]
			var path: String = theme_dir.path_join(name)
			for font_name: String in ["regular", "semibold", "bold", "extrabold", "numeric"]:
				var font: FontVariation = (
					load("res://assets/fonts/inter_%s.tres" % font_name) as FontVariation
				)
				font.set_id_for_path(path, "font_" + font_name)
			result = ResourceSaver.save(build_theme(high_contrast, percent), path)
			if result != OK:
				return result
	var file: FileAccess = FileAccess.open(css_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(css_text())
	result = file.get_error()
	file.close()
	return result
