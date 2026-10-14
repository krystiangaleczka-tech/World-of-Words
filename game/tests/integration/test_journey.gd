extends GutTest

const JOURNEY: Script = preload("res://features/journey/journey.gd")
const NAV: Script = preload("res://services/nav.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const CATALOG: Script = preload("res://tests/fixtures/journey/catalog.gd")
const PATH: String = "user://t0245-journey.json"
const FIXTURE: String = "res://tests/fixtures/content"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class JourneyConfig:
	extends "res://services/config.gd"
	var piece_capacity: int = -1

	func get_int(key: StringName) -> int:
		if key == &"meta.postcard.pieces" and piece_capacity >= 0:
			return piece_capacity
		return 2 if key == &"unlocks.journey_slot" else super.get_int(key)


var _save: SAVE
var _content: CONTENT
var _config: CONFIG
var _nav: NAV
var _host: Control
var _journey: ScreenScaffold
var _old_locale: String
var _old_motion: bool
var _old_low: bool
var _old_pseudo: bool
var _pseudo_settings: Dictionary = {}


func before_each() -> void:
	_clean()
	_old_locale = TranslationServer.get_locale()
	_old_motion = Tokens.reduced_motion
	_old_low = OS.low_processor_usage_mode
	_old_pseudo = TranslationServer.pseudolocalization_enabled
	for key: String in GalleryShell.OPTIONS:
		var path: String = GalleryShell.PSEUDO + key
		_pseudo_settings[path] = (
			ProjectSettings.get_setting(path) if ProjectSettings.has_setting(path) else null
		)
		ProjectSettings.set_setting(path, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	TranslationServer.set_locale("pl")
	Tokens.reduced_motion = true
	_save = SAVE.new()
	_content = CATALOG.new()
	_config = JourneyConfig.new()
	_nav = NAV.new()
	_host = Control.new()
	_host.size = Vector2(1080, 1920)
	for node: Node in [_save, _content, _config, _nav, _host]:
		add_child_autofree(node)
	for service: ServiceStub in [_save, _content, _config, _nav]:
		service.initialize(FixedClock.new())
	_save.configure(
		SaveStorage.new(PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert_eq(_save.load(), OK)
	assert_eq(_content.load_manifest("pl", FIXTURE), OK)
	assert_eq(_config.load(), OK)
	_write(2, 1)
	_nav.configure(_save, _config, _content)
	assert_eq(_nav.configure_p2(func() -> Error: return OK, false), OK)
	assert_eq(_nav.start(_host, FIXTURE), OK)
	assert_eq(_nav.go_to_screen(NAV.Screen.JOURNEY), OK)
	_journey = _nav.mounted_screen()


func after_each() -> void:
	if is_instance_valid(_nav):
		_nav.free()
	await get_tree().process_frame
	for path: String in _pseudo_settings:
		ProjectSettings.set_setting(path, _pseudo_settings[path])
	_pseudo_settings.clear()
	TranslationServer.reload_pseudolocalization()
	TranslationServer.pseudolocalization_enabled = _old_pseudo
	TranslationServer.set_locale(_old_locale)
	Tokens.reduced_motion = _old_motion
	OS.low_processor_usage_mode = _old_low
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _write(slot: int, highest: int) -> void:
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.current_slot = slot
	progress.by_lang.pl.highest_completed_slot = highest
	progress.by_lang.pl.completed_slot = highest
	progress.by_lang.pl.stars = 7
	progress.by_lang.pl.location_pieces = {"harbor": 1, "market": 2, "hill": 0}
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)


func _row(id: String) -> Card:
	return _journey.find_child("Location_" + id, true, false) as Card


func _child(row: Node, name_of_node: String) -> Node:
	return row.find_child(name_of_node, true, false)


func _art() -> Texture2D:
	var image: GradientTexture2D = GradientTexture2D.new()
	image.width = 600
	image.height = 400
	image.gradient = Gradient.new()
	return image


func test_real_nav_injection_header_and_back_return_home() -> void:
	assert_eq(_nav.current_screen(), NAV.Screen.JOURNEY)
	assert_eq(_journey.top_bar.title_key, "journey.preview.region")
	assert_eq(_journey.find_child("Stars", true, false).value, 7)
	assert_eq(_journey.find_child("Stars", true, false).autowrap_mode, TextServer.AUTOWRAP_OFF)
	_journey.find_child("Back", true, false).pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.HOME)
	assert_not_null(_nav.mounted_screen())


func test_complete_current_locked_cards_have_explicit_copy_and_no_replay() -> void:
	assert_eq(_row("harbor").sublabel_key, "journey.location.complete")
	assert_eq(_row("market").sublabel_key, "journey.location.current")
	assert_eq(_row("hill").sublabel_key, "journey.location.locked")
	assert_true(_row("market").highlighted)
	assert_true(_row("hill").disabled)
	assert_eq(_child(_row("hill"), "Availability").text, "Poziom odblokowania: 3")
	assert_eq(_child(_row("harbor"), "CompletedLevels").text, "Ukończone poziomy: 1–1 (1 / 1)")
	assert_eq(_child(_row("market"), "CompletedLevels").text, "Ukończone poziomy: 0 / 1")
	for id: String in ["harbor", "market", "hill"]:
		assert_false(_row(id).tappable)
		_row(id).pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.JOURNEY)
	assert_eq(_nav.level_slot(), 2)


func test_multi_level_location_counts_and_guarded_back_failure() -> void:
	_content.grouped = true
	_journey.refresh()
	assert_eq(_row("harbor").sublabel_key, "journey.location.current")
	assert_eq(_child(_row("harbor"), "CompletedLevels").text, "Ukończone poziomy: 1–1 (1 / 2)")
	assert_null(_row("market"))
	_nav.remove_from_group(NAV.BACK_GROUP)
	_journey.find_child("Back", true, false).pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.JOURNEY)
	assert_eq(
		_journey.find_child("Summary", true, false).text,
		"Nie można teraz wrócić. Spróbuj ponownie."
	)


func test_committed_stars_pieces_ignore_uncommitted_values_without_writes() -> void:
	var primary: String = FileAccess.get_file_as_string(PATH)
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.stars = 99
	progress.by_lang.pl.location_pieces.market = 4
	assert_eq(_save.set_section(&"progress", progress), OK)
	_journey.refresh()
	assert_eq(_journey.find_child("Stars", true, false).value, 7)
	assert_eq(_child(_row("market"), "Pieces").text, "Pocztówka: 2 / 4")
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	assert_eq(_save.flush(), OK)
	primary = FileAccess.get_file_as_string(PATH)
	_journey.refresh()
	assert_eq(_journey.find_child("Stars", true, false).value, 99)
	assert_eq(_child(_row("market"), "PieceProgress").value, 1.0)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)


func test_campaign_completion_does_not_invent_postcard_credits() -> void:
	_write(4, 3)
	_journey.refresh()
	assert_eq(_row("harbor").sublabel_key, "journey.location.complete")
	assert_eq(_child(_row("harbor"), "Pieces").text, "Pocztówka: 1 / 4")
	assert_eq(_journey.find_child("Summary", true, false).text, "Region ukończony")
	assert_not_null(_row("hill"), "terminal slot retains the last region")


func test_only_current_region_is_visible() -> void:
	_content.second_region = true
	_journey.refresh()
	assert_not_null(_row("harbor"))
	assert_not_null(_row("market"))
	assert_null(_row("hill"))
	_write(3, 2)
	_journey.refresh()
	assert_null(_row("harbor"))
	assert_null(_row("market"))
	assert_not_null(_row("hill"))
	assert_eq(_journey.top_bar.title_key, "journey.preview.region_two")


func test_legacy_missing_art_and_injected_thumbnail_progress() -> void:
	assert_not_null(_child(_row("market"), "MissingArt"))
	var preview: ScreenScaffold = JOURNEY.new()
	preview.configure(
		_save, _content, _config, _nav, func(_location: Dictionary) -> Texture2D: return _art()
	)
	_host.add_child(preview)
	var card: Card = preview.find_child("Location_market", true, false)
	var postcard: LocationPostcard = _child(card, "Postcard")
	assert_eq(postcard.preset, &"thumb")
	assert_eq(postcard.pieces_revealed, 2)
	assert_eq(postcard.pieces_total, 4)
	var legacy: CONTENT = CONTENT.new()
	add_child_autofree(legacy)
	assert_eq(legacy.load_manifest("pl", FIXTURE), OK)
	var screen: ScreenScaffold = JOURNEY.new()
	screen.configure(_save, legacy, _config, _nav)
	_host.add_child(screen)
	assert_eq(screen.top_bar.title_key, "journey.main.title")
	assert_not_null(screen.find_child("Location_campaign", true, false))


func test_missing_unloaded_services_clear_rows_and_preserve_back() -> void:
	for missing: int in 3:
		var screen: ScreenScaffold = JOURNEY.new()
		screen.configure(
			null if missing == 0 else _save,
			null if missing == 1 else _content,
			null if missing == 2 else _config,
			_nav
		)
		_host.add_child(screen)
		assert_true(screen.find_child("Unavailable", true, false).visible)
		assert_eq(screen.find_child("LocationList", true, false).get_child_count(), 0)
	var unloaded_save: SAVE = SAVE.new()
	var unloaded_content: CONTENT = CONTENT.new()
	for service: Node in [unloaded_save, unloaded_content]:
		add_child_autofree(service)
	for missing: int in 2:
		var unavailable: ScreenScaffold = JOURNEY.new()
		unavailable.configure(
			unloaded_save if missing == 0 else _save,
			unloaded_content if missing == 1 else _content,
			_config,
			_nav
		)
		_host.add_child(unavailable)
		assert_true(unavailable.find_child("Unavailable", true, false).visible)
	var unloaded: CONFIG = CONFIG.new()
	add_child_autofree(unloaded)
	var screen: ScreenScaffold = JOURNEY.new()
	screen.configure(_save, _content, unloaded, _nav)
	_host.add_child(screen)
	assert_true(screen.find_child("Unavailable", true, false).visible)
	assert_eq(_save.set_setting(&"language", "en"), OK)
	assert_eq(_save.flush(), OK)
	_journey.refresh()
	assert_true(_journey.find_child("Unavailable", true, false).visible)
	assert_null(_row("market"))
	_journey.find_child("Back", true, false).pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.HOME)


func test_unsupported_piece_capacity_shows_unavailable_not_zero_progress() -> void:
	for capacity: int in [0, LocationPostcard.MAX_PIECES + 1]:
		var config: JourneyConfig = JourneyConfig.new()
		config.piece_capacity = capacity
		add_child_autofree(config)
		assert_eq(config.load(), OK)
		var screen: ScreenScaffold = JOURNEY.new()
		screen.configure(_save, _content, config, _nav)
		_host.add_child(screen)
		assert_true(screen.find_child("Unavailable", true, false).visible)
		assert_eq(screen.find_child("LocationList", true, false).get_child_count(), 0)


func test_locale_refresh_exit_reentry_preserves_owned_body_cleanup() -> void:
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(_child(_row("market"), "Pieces").text, "Postcard: 2 / 4")
	var old: WeakRef = weakref(_child(_row("market"), "PieceProgress"))
	_journey.refresh()
	await get_tree().process_frame
	assert_null(old.get_ref(), "caller-owned detached Card bodies are disposed on refresh")
	old = weakref(_child(_row("market"), "PieceProgress"))
	_host.remove_child(_journey)
	await get_tree().process_frame
	assert_null(old.get_ref(), "detached bodies are disposed on exit")
	_host.add_child(_journey)
	await get_tree().process_frame
	assert_not_null(_row("market"))
	assert_eq(_child(_row("market"), "Pieces").text, "Postcard: 2 / 4")


func test_all_three_safe_layouts_hc130_pseudo35_scroll_to_last_location() -> void:
	TranslationServer.pseudolocalization_enabled = true
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = dimensions
		add_child_autofree(viewport)
		var screen: ScreenScaffold = JOURNEY.new()
		screen.debug_insets = Rect2(Vector2(24, 48), Vector2(24, 48))
		screen.theme = load("res://ui/theme/generated/theme_hc_130.tres") as Theme
		screen.configure(
			_save, _content, _config, _nav, func(_location: Dictionary) -> Texture2D: return _art()
		)
		viewport.add_child(screen)
		for frame: int in 6:
			await get_tree().process_frame
		var scroll: ScrollContainer = screen.find_child("Locations", true, false)
		var list: VBoxContainer = screen.find_child("LocationList", true, false)
		var last: Card = screen.find_child("Location_hill", true, false)
		assert_lte(list.size.x, scroll.size.x)
		assert_true(screen.body.get_global_rect().encloses(scroll.get_global_rect()))
		var heading: Label = screen.find_child("RegionTitle", true, false)
		assert_true(screen.top_bar.fits or heading.visible)
		assert_eq(heading.text, screen.tr(screen.top_bar.title_key))
		var origin: Vector2 = scroll.get_global_rect().get_center()
		# Godot 4.7 ScrollContainer consumes the mouse events emitted by touch emulation.
		var touch: InputEventMouseButton = InputEventMouseButton.new()
		touch.button_index = MOUSE_BUTTON_LEFT
		touch.button_mask = MOUSE_BUTTON_MASK_LEFT
		touch.position = origin
		touch.pressed = true
		viewport.push_input(touch, true)
		for step: int in [1, 2]:
			var drag: InputEventMouseMotion = InputEventMouseMotion.new()
			drag.button_mask = MOUSE_BUTTON_MASK_LEFT
			drag.position = origin + Vector2.UP * Tokens.Touch.MIN_TARGET * step
			drag.relative = Vector2.UP * Tokens.Touch.MIN_TARGET
			viewport.push_input(drag, true)
		assert_gt(
			scroll.scroll_vertical,
			0,
			"touch-emulation drag starting on a passive location scrolls the list"
		)
		touch.position = origin + Vector2.UP * Tokens.Touch.MIN_TARGET * 2
		touch.pressed = false
		touch.button_mask = 0
		viewport.push_input(touch, true)
		scroll.ensure_control_visible(last)
		for frame: int in 2:
			await get_tree().process_frame
		assert_lte(last.get_global_rect().end.y, scroll.get_global_rect().end.y)
