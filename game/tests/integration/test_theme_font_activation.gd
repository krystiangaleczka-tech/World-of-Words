extends GutTest

const SOURCE: GDScript = preload("res://ui/tokens.gd")
const NAV_SCRIPT: GDScript = preload("res://services/nav.gd")
const SAVE_SCRIPT: GDScript = preload("res://services/save.gd")
const CONFIG_SCRIPT: GDScript = preload("res://services/config.gd")
const CONTENT_SCRIPT: GDScript = preload("res://services/content.gd")
const NAMES: Dictionary = {
	"regular": 400, "semibold": 600, "bold": 700, "extrabold": 800, "numeric": 700
}
const SAVE_PATH: String = "user://t0208-save.json"

var _previous_low_mode: bool


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1_790_000_000

	func monotonic_msec() -> int:
		return 0


func before_each() -> void:
	_previous_low_mode = OS.low_processor_usage_mode


func after_each() -> void:
	OS.low_processor_usage_mode = _previous_low_mode
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)


func test_pinned_font_and_shipped_notice() -> void:
	assert_eq(
		FileAccess.get_sha256("res://assets/fonts/Inter.ttf"),
		"29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031"
	)
	assert_eq(
		FileAccess.get_sha256("res://assets/fonts/OFL.txt"),
		"5b9321a4298cfeb6b34354164a1c3afc3db114569984c502b9b35d988fd58c57"
	)
	var notice: Resource = load("res://assets/fonts/font_license.tres")
	assert_eq(
		notice.get_meta(&"ofl_notice"), FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	)
	var base: FontFile = load("res://assets/fonts/Inter.res") as FontFile
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(base.data)
	assert_eq(digest.finish().hex_encode(), FileAccess.get_sha256("res://assets/fonts/Inter.ttf"))
	var supported: String = base.get_supported_chars()
	for letter: String in "ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ äöüß ÄÖÜẞ „”–…0123456789":
		assert_true(letter in supported, "Native font coverage: " + letter)


func test_all_variations_have_native_axes_and_features() -> void:
	var server: TextServer = TextServerManager.get_primary_interface()
	for name: String in NAMES:
		var font: FontVariation = _font(name)
		assert_not_null(font)
		assert_eq(font.base_font.resource_path, "res://assets/fonts/Inter.res")
		assert_eq(font.variation_opentype.get(server.name_to_tag("wght")), NAMES[name])
		assert_eq(font.variation_opentype.get(server.name_to_tag("opsz")), 14)
		assert_eq(font.variation_embolden, 0.0)
		for tag: String in ["cv08", "cv05"]:
			assert_eq(font.opentype_features.get(server.name_to_tag(tag)), 1)
	var numeric: FontVariation = _font("numeric")
	assert_eq(numeric.opentype_features.get(server.name_to_tag("tnum")), 1)
	assert_eq(numeric.opentype_features.get(server.name_to_tag("pnum")), 0)


func test_native_tabular_shaping_and_i_l_alternates() -> void:
	var numeric: FontVariation = _font("numeric")
	var width: float = numeric.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	for digit: String in "0123456789":
		assert_almost_eq(
			numeric.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x, width, 0.01
		)
	var normal: FontVariation = _font("regular")
	assert_ne(
		normal.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x,
		normal.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	)
	var features_off: FontVariation = FontVariation.new()
	features_off.base_font = normal.base_font
	features_off.variation_opentype = normal.variation_opentype
	for letter: String in ["I", "l"]:
		assert_ne(_glyph(letter, normal), _glyph(letter, features_off), "Alternate: " + letter)


func test_themes_bind_fonts_at_every_size_and_contrast() -> void:
	var weights: Dictionary = (
		(SOURCE.get_script_constant_map()["Type"] as GDScript).get_script_constant_map()
	)
	for mode: String in ["default", "hc"]:
		for percent: int in [100, 115, 130]:
			var theme: Theme = (
				load("res://ui/theme/generated/theme_%s_%d.tres" % [mode, percent]) as Theme
			)
			assert_same(theme.default_font, _font("regular"))
			assert_same(theme.get_font(&"font", &"Label"), _font("regular"))
			assert_same(theme.get_font(&"font", &"Button"), _font("semibold"))
			for token: String in [
				"DISPLAY",
				"TITLE",
				"SUBTITLE",
				"BODY",
				"LABEL",
				"CAPTION",
				"NUMERIC",
				"TILE_LETTER",
				"PREVIEW"
			]:
				var name: String = (
					"numeric"
					if token == "NUMERIC"
					else str(NAMES.find_key(weights[token + "_WEIGHT"]))
				)
				assert_same(theme.get_font(StringName(token), &"Type"), _font(name))
			assert_same(theme.get_font(&"font", &"Numeric"), _font("numeric"))


func test_project_activation_and_native_settings() -> void:
	assert_eq(
		ProjectSettings.get_setting("gui/theme/custom"),
		"res://ui/theme/generated/theme_default_100.tres"
	)
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"))
	assert_true(ProjectSettings.get_setting("application/run/low_processor_mode"))
	assert_eq(ProjectSettings.get_setting("audio/general/ios/session_category"), 0)
	assert_same(ThemeDB.get_project_theme().default_font, _font("regular"))


func test_nav_applies_low_mode_before_screen_signal() -> void:
	var nav: NAV_SCRIPT = _configured_nav()
	var observations: Array[bool] = []
	var listener: Callable = func(_screen: int) -> void:
		observations.append(OS.low_processor_usage_mode)
	nav.screen_changed.connect(listener)
	var host: Node = Node.new()
	add_child_autofree(host)
	assert_eq(nav.start(host, "res://tests/fixtures/content"), OK)
	assert_false(OS.low_processor_usage_mode)
	assert_eq(nav.go_home(), OK)
	assert_true(OS.low_processor_usage_mode)
	assert_eq(nav.go_to_level(1), OK)
	assert_false(OS.low_processor_usage_mode)
	assert_eq(observations, [false, true, false])
	nav.screen_changed.disconnect(listener)


func _font(name: String) -> FontVariation:
	return load("res://assets/fonts/inter_%s.tres" % name) as FontVariation


func _glyph(text: String, font: FontVariation) -> int:
	var line: TextLine = TextLine.new()
	line.add_string(text, font, 84)
	var glyphs: Array[Dictionary] = (
		TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid())
	)
	assert_eq(glyphs.size(), 1)
	return int(glyphs[0]["index"])


func test_failed_boot_still_uses_low_processor_mode() -> void:
	OS.low_processor_usage_mode = false
	var nav: NAV_SCRIPT = _configured_nav()
	var host: Node = Node.new()
	add_child_autofree(host)
	assert_ne(nav.start(host, "res://tests/fixtures/missing_t0208_content"), OK)
	assert_true(OS.low_processor_usage_mode)
	assert_eq(nav.current_screen(), nav.Screen.BOOT)


func _configured_nav() -> NAV_SCRIPT:
	var clock: FixedClock = FixedClock.new()
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	var nav: NAV_SCRIPT = NAV_SCRIPT.new()
	for service: ServiceStub in [save, config, content, nav]:
		add_child_autofree(service)
		service.initialize(clock)
	save.configure(
		SaveStorage.new(SAVE_PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	nav.configure(save, config, content)
	return nav
