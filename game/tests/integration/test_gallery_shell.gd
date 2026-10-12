extends GutTest

const SHELL: PackedScene = preload("res://ui/gallery/gallery.tscn")
var _locale: String
var _pseudo: bool
var _reduced: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_reduced = Tokens.reduced_motion


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _reduced


func _gallery() -> GalleryShell:
	var gallery: GalleryShell = SHELL.instantiate() as GalleryShell
	add_child_autofree(gallery)
	return gallery


func test_default_samples_and_maximum_geometry() -> void:
	var gallery: GalleryShell = _gallery()
	await get_tree().process_frame
	assert_eq(gallery.preview_viewport().size, Vector2i(1080, 2340))
	var screen: ScreenScaffold = gallery.preview_screen()
	assert_eq(screen.theme.resource_name, "Ceramic_default_100")
	assert_eq((screen.get_node("Safe/Body/Pangram") as Label).text, "ZAŻÓŁĆ GĘŚLĄ JAŹŃ")
	assert_eq((screen.get_node("Safe/Body/Restore") as Label).text, "Przywróć zakupy")
	var numeric: Label = screen.get_node("Safe/Body/Numeric") as Label
	assert_eq(numeric.theme_type_variation, &"Numeric")
	assert_true(numeric.text.contains("99 999"))
	var wheel: LetterWheelView = screen.get_node("Safe/Body/EightLetterWheel") as LetterWheelView
	assert_eq(wheel.tile_order().size(), 8)
	var board: BoardView = screen.get_node("Safe/Body/MaxGrid") as BoardView
	assert_not_null(board.cell_node(Vector2i(LevelData.MAX_GRID - 1, LevelData.MAX_GRID - 1)))


func test_switch_matrix_exact_preview_theme_language_and_insets() -> void:
	var gallery: GalleryShell = _gallery()
	for layout: StringName in GalleryShell.SIZES:
		for language: StringName in GalleryShell.LANGUAGES:
			for hc: bool in [false, true]:
				for percent: int in GalleryShell.PERCENTS:
					assert_eq(gallery.configure(layout, language, hc, percent, true, true), OK)
					await get_tree().process_frame
					assert_eq(gallery.preview_viewport().size, GalleryShell.SIZES[layout])
					assert_eq(
						gallery.preview_screen().theme.resource_name,
						"Ceramic_%s_%d" % ["hc" if hc else "default", percent]
					)
					assert_eq(TranslationServer.get_locale(), "pl" if language == &"PL" else "en")
					assert_eq(TranslationServer.pseudolocalization_enabled, language == &"PSEUDO")
					assert_true(Tokens.reduced_motion)
					assert_eq(
						gallery.preview_screen().debug_insets,
						Rect2(Vector2.ONE * Tokens.Space.M, Vector2.ONE * Tokens.Space.L)
					)
					var caption: String = (
						(gallery.preview_screen().get_node("Safe/Body/Restore") as Label).text
					)
					if language == &"PSEUDO":
						assert_ne(caption, "Restore purchases")
						assert_eq(
							(
								(gallery.preview_screen().get_node("Safe/Body/Restore") as Label)
								. auto_translate_mode
							),
							Node.AUTO_TRANSLATE_MODE_DISABLED
						)
	assert_eq(ProjectSettings.get_setting(GalleryShell.PSEUDO + "expansion_ratio"), 0.35)
	assert_eq(ProjectSettings.get_setting(GalleryShell.PSEUDO + "replace_with_accents"), true)


func test_invalid_configuration_and_page_replacement() -> void:
	var gallery: GalleryShell = _gallery()
	var previous: ScreenScaffold = gallery.preview_screen()
	assert_eq(gallery.configure(&"BAD", &"PL", true, 130, true, true), ERR_INVALID_PARAMETER)
	assert_eq(gallery.configure(&"REGULAR", &"DE", true, 130, true, true), ERR_INVALID_PARAMETER)
	assert_eq(gallery.configure(&"REGULAR", &"PL", true, 140, true, true), ERR_INVALID_PARAMETER)
	assert_eq(
		gallery.configure(&"REGULAR", &"PL", true, 130, true, true, &"BAD"), ERR_INVALID_PARAMETER
	)
	assert_same(gallery.preview_screen(), previous)
	for page: StringName in GalleryShell.PAGES:
		assert_eq(gallery.configure(&"COMPACT", &"EN", false, 100, false, false, page), OK)
		assert_eq(gallery.preview_viewport().get_child_count(), 1)
		assert_false(gallery.preview_screen().is_queued_for_deletion())
	await get_tree().process_frame
	assert_false(is_instance_valid(previous))


func test_exit_restores_global_review_settings_and_resize_keeps_geometry() -> void:
	var locale: String = TranslationServer.get_locale()
	var pseudo: bool = TranslationServer.pseudolocalization_enabled
	var reduced: bool = Tokens.reduced_motion
	var settings: Dictionary[String, Variant] = {}
	for key: String in GalleryShell.OPTIONS:
		var path: String = GalleryShell.PSEUDO + key
		settings[path] = (
			ProjectSettings.get_setting(path) if ProjectSettings.has_setting(path) else null
		)
	var gallery: GalleryShell = _gallery()
	gallery.configure(&"TABLET", &"PSEUDO", true, 130, not reduced, true)
	gallery.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	gallery.size = Vector2(800, 1200)
	await get_tree().process_frame
	assert_eq(gallery.preview_viewport().size, Vector2i(1440, 1920))
	assert_eq(gallery.preview_screen().size, Vector2(1440, 1920))
	gallery.free()
	assert_eq(TranslationServer.get_locale(), locale)
	assert_eq(TranslationServer.pseudolocalization_enabled, pseudo)
	assert_eq(Tokens.reduced_motion, reduced)
	for path: String in settings:
		if settings[path] == null:
			assert_false(ProjectSettings.has_setting(path))
		else:
			assert_eq(ProjectSettings.get_setting(path), settings[path])


func test_pre_ready_configuration_and_native_switch_event() -> void:
	var gallery: GalleryShell = SHELL.instantiate() as GalleryShell
	assert_eq(gallery.configure(&"TABLET", &"EN", true, 115, false, false), OK)
	add_child_autofree(gallery)
	await get_tree().process_frame
	assert_eq(gallery.preview_viewport().size, Vector2i(1440, 1920))
	var contrast: CheckButton = gallery.find_child("contrast", true, false) as CheckButton
	assert_true(contrast.button_pressed)
	contrast.button_pressed = false
	assert_eq(gallery.preview_screen().theme.resource_name, "Ceramic_default_115")
	var foreign: Translation = Translation.new()
	foreign.locale = "en"
	foreign.add_message("gallery.test.foreign", "External owner")
	TranslationServer.add_translation(foreign)
	gallery.free()
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = false
	assert_eq(TranslationServer.translate("gallery.test.foreign"), "External owner")
	TranslationServer.remove_translation(foreign)
