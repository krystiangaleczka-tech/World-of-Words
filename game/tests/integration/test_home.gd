extends GutTest

const HOME: Script = preload("res://features/home/home.gd")
const NAV: Script = preload("res://services/nav.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const PATH: String = "user://t0244-home.json"
const FIXTURE: String = "res://tests/fixtures/content"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class HomeConfig:
	extends "res://services/config.gd"

	func get_int(key: StringName) -> int:
		return 2 if key == &"unlocks.journey_slot" else super.get_int(key)


var _save: SAVE
var _content: CONTENT
var _config: CONFIG
var _nav: NAV
var _host: Control
var _home: ScreenScaffold
var _old_locale: String
var _old_motion: bool
var _old_low: bool


func before_each() -> void:
	_clean()
	_old_locale = TranslationServer.get_locale()
	_old_motion = Tokens.reduced_motion
	_old_low = OS.low_processor_usage_mode
	Tokens.reduced_motion = true
	TranslationServer.set_locale("pl")
	_save = SAVE.new()
	_content = CONTENT.new()
	_config = HomeConfig.new()
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
	_write_progress(2, 3)
	_nav.configure(_save, _config, _content)
	assert_eq(_nav.configure_p2(func() -> Error: return OK, false), OK)
	assert_eq(_nav.start(_host, FIXTURE), OK)
	_home = _nav.mounted_screen() as ScreenScaffold


func after_each() -> void:
	if is_instance_valid(_nav):
		_nav.free()
	await get_tree().process_frame
	TranslationServer.set_locale(_old_locale)
	Tokens.reduced_motion = _old_motion
	OS.low_processor_usage_mode = _old_low
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _write_progress(slot: int, pieces: int) -> void:
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.current_slot = slot
	progress.by_lang.pl.highest_completed_slot = slot - 1
	progress.by_lang.pl.completed_slot = slot - 1
	progress.by_lang.pl.location_pieces = {"campaign": pieces}
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)


func _control(node_name: String) -> Node:
	return _home.find_child(node_name, true, false)


func _art() -> Texture2D:
	var image: GradientTexture2D = GradientTexture2D.new()
	image.width = 600
	image.height = 400
	image.gradient = Gradient.new()
	return image


func _preview(image: Texture2D) -> ScreenScaffold:
	var home: ScreenScaffold = HOME.new()
	home.configure(
		_save, _content, _config, _nav, func(_location: Dictionary) -> Texture2D: return image
	)
	_host.add_child(home)
	return home


func test_real_nav_mount_injected_committed_values_without_writes() -> void:
	assert_not_null(_home)
	assert_eq(_nav.current_screen(), NAV.Screen.HOME)
	assert_true(_control("MissingArt").visible)
	assert_false(_control("Postcard").visible)
	assert_eq(_control("NextLevel").text, "Poziom: 2")
	assert_eq(_control("Location").text, "Twoja podróż")
	assert_eq(_control("Progress").text, "Pocztówka: 3 / 4")
	var primary: String = FileAccess.get_file_as_string(PATH)
	var economy: Dictionary = _save.get_section(&"economy")
	economy.coins = 12345
	assert_eq(_save.set_section(&"economy", economy), OK)
	_home.refresh()
	assert_eq(_control("Coins").value, 0, "uncommitted wallet values stay invisible")
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	assert_eq(_save.flush(), OK)
	primary = FileAccess.get_file_as_string(PATH)
	_home.refresh()
	assert_eq(_control("Coins").value, 12345)
	assert_eq(_control("Coins").autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)


func test_play_resumes_actual_partial_board_at_exact_current_slot() -> void:
	var board: BoardState = BoardState.new(_content.level_for_slot(2))
	var cell: Vector2i = board.get_level().word_cells(0)[0]
	board.reveal_cell(cell)
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.level_state = board.to_dict()
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)
	_control("Play").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_nav.level_slot(), 2)
	var level: LevelScreen = _nav.mounted_screen()
	assert_true(level.controller.get_board().revealed_cells().has(cell))


func test_missing_content_disables_play_and_displays_explanation() -> void:
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/missing"), ERR_FILE_NOT_FOUND)
	# A slot can become unavailable without changing the saved campaign pointer.
	_content.free()
	_control("Play").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.HOME)
	assert_eq(_control("Status").text, "Postęp jest teraz niedostępny. Spróbuj ponownie później.")
	assert_true(_control("Play").disabled)


func test_failed_navigation_is_inline_and_play_reads_latest_committed_slot() -> void:
	_nav.remove_from_group(NAV.BACK_GROUP)
	_control("Play").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.HOME)
	assert_eq(_control("Status").text, "Nie można teraz otworzyć poziomu. Spróbuj ponownie.")
	_nav.add_to_group(NAV.BACK_GROUP)
	_write_progress(3, 3)
	_control("Play").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_nav.level_slot(), 3)


func test_terminal_slot_disables_play_without_replaying_last_level() -> void:
	_write_progress(4, 8)
	_home.refresh()
	assert_true(_control("Play").disabled)
	assert_false(_control("NextLevel").visible)
	assert_eq(_control("Status").text, "Wszystkie dostępne poziomy ukończone.")
	_control("Play").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.HOME)


func test_art_partial_complete_and_invalid_services_are_safe() -> void:
	var home: ScreenScaffold = _preview(_art())
	var postcard: LocationPostcard = home.find_child("Postcard", true, false)
	assert_true(postcard.visible)
	assert_eq(postcard.pieces_revealed, 3)
	assert_eq(postcard.pieces_total, 4)
	assert_not_null(home.background)
	_write_progress(2, 8)
	home.refresh()
	assert_eq(postcard.state, &"complete")
	var unavailable: ScreenScaffold = HOME.new()
	unavailable.configure(null, null, null, _nav)
	_host.add_child(unavailable)
	assert_true(unavailable.find_child("Play", true, false).disabled)
	assert_true(unavailable.find_child("Status", true, false).visible)


func test_locale_reentry_and_unbuilt_destinations() -> void:
	assert_false(_control("Journey").visible)
	assert_true(_control("Settings").disabled)
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(_control("NextLevel").text, "Level: 2")
	assert_eq(_control("Play").text, "Play")
	_host.remove_child(_home)
	TranslationServer.set_locale("pl")
	_host.add_child(_home)
	await get_tree().process_frame
	assert_eq(_control("NextLevel").text, "Poziom: 2")
	assert_eq(_control("Play").text, "Graj")


func test_three_layout_classes_hc130_pseudo_safe_scroll_and_no_horizontal_overflow() -> void:
	_home.queue_free()
	TranslationServer.set_pseudolocalization_enabled(true)
	for dimensions: Vector2 in [Vector2(1080, 1920), Vector2(1080, 2340), Vector2(1440, 1920)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(dimensions)
		add_child_autofree(viewport)
		var home: ScreenScaffold = HOME.new()
		home.theme = load("res://ui/theme/generated/theme_hc_130.tres") as Theme
		home.debug_insets = Rect2(Vector2(24, 48), Vector2(24, 48))
		home.configure(
			_save, _content, _config, _nav, func(_l: Dictionary) -> Texture2D: return _art()
		)
		viewport.add_child(home)
		for frame: int in 5:
			await get_tree().process_frame
		var scroll: ScrollContainer = home.find_child("Content", true, false)
		var column: VBoxContainer = home.find_child("Column", true, false)
		var play: PrimaryButton = home.find_child("Play", true, false)
		assert_lte(column.size.x, scroll.size.x)
		assert_true(home.body.get_global_rect().encloses(scroll.get_global_rect()))
		scroll.ensure_control_visible(play)
		for frame: int in 2:
			await get_tree().process_frame
		assert_true(scroll.get_global_rect().encloses(play.get_global_rect()))
		assert_gte(play.size.y, float(Tokens.Touch.MIN_TARGET))
	TranslationServer.set_pseudolocalization_enabled(false)
