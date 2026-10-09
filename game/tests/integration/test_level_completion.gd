extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const NAV_SCRIPT: Script = preload("res://services/nav.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _storage: MemoryStorage
var _save: SAVE_SCRIPT
var _content: TrackedContent
var _bus: Node


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var fail: bool = false
	var writes: int = 0

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		writes += 1
		if fail:
			return ERR_FILE_CANT_WRITE
		document = JSON.parse_string(text)
		return OK


func before_each() -> void:
	_storage = MemoryStorage.new()
	_save = SAVE_SCRIPT.new()
	_content = TrackedContent.new()
	_bus = EVENTS_SCRIPT.new()
	add_child_autofree(_save)
	add_child_autofree(_content)
	add_child_autofree(_bus)
	_save.initialize(Clock.new())
	_save.configure(_storage)
	assert_eq(_save.load(), OK)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)


func _slot(slot: int) -> void:
	var section: Dictionary = _save.get_section(&"progress")
	section["by_lang"]["pl"]["current_slot"] = slot
	assert_eq(_save.set_section(&"progress", section), OK)
	assert_eq(_save.flush(), OK)


func _new_scene() -> LevelScreen:
	var screen: LevelScreen = load("res://features/level/level.tscn").instantiate() as LevelScreen
	return screen


func _scene(slot: int = 1) -> LevelScreen:
	var screen: LevelScreen = _new_scene()
	screen.configure(_save, _content, slot, _bus)
	add_child_autofree(screen)
	return screen


class TrackedContent:
	extends "res://services/content.gd"
	var requested: Array[int] = []
	var unavailable: int = 0

	func level_for_slot(slot: int) -> LevelData:
		requested.append(slot)
		return null if slot == unavailable else super.level_for_slot(slot)


class NavigationFailure:
	extends Node
	var calls: int = 0
	var error: Error = ERR_UNAVAILABLE

	func go_to_level(_slot_number: int) -> Error:
		calls += 1
		return error


func _finish(screen: LevelScreen) -> void:
	var level: LevelData = screen.controller.get_board().get_level()
	for index: int in level.word_count():
		screen.controller.submit(_tiles(level, level.word(index)))


func _tiles(level: LevelData, word: String) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var letters: PackedStringArray = level.get_letters()
	for character: String in word:
		for index: int in letters.size():
			if letters[index] == character and index not in result:
				result.append(index)
				break
	return result


func test_primary_button_catalog_states() -> void:
	var button: PrimaryButton = load("res://ui/components/PrimaryButton.tscn").instantiate()
	button.text_key = "level.complete.continue"
	add_child_autofree(button)
	assert_eq(button.text, button.tr("level.complete.continue"))
	assert_eq(button.accessibility_name, button.text)
	assert_eq(
		(button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.Palette.PRIMARY
	)
	assert_eq(button.get_theme_color("font_color"), Tokens.Palette.ON_PRIMARY)
	assert_eq(
		(button.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color, Tokens.Palette.SURFACE_ALT
	)
	assert_eq(button.get_theme_color("font_disabled_color"), Tokens.Palette.TEXT_MUTED)
	assert_false((button.get_theme_stylebox("focus") as StyleBoxFlat).draw_center)
	watch_signals(button)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"ui_accept"
	press.pressed = true
	var release: InputEventAction = InputEventAction.new()
	release.action = &"ui_accept"
	release.pressed = false
	button.grab_focus()
	await get_tree().process_frame
	button.get_viewport().push_input(press)
	button.get_viewport().push_input(release)
	assert_signal_emit_count(button, "pressed", 1)
	button.disabled = true
	button.get_viewport().push_input(press)
	button.get_viewport().push_input(release)
	assert_signal_emit_count(button, "pressed", 1)


func test_completion_preloads_and_continue_routes_once() -> void:
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var nav: NAV_SCRIPT = NAV_SCRIPT.new()
	var host: Control = Control.new()
	add_child_autofree(config)
	add_child_autofree(nav)
	add_child_autofree(host)
	nav.configure(_save, config, _content)
	assert_eq(nav.start(host, "res://tests/fixtures/content"), OK)
	var screen: LevelScreen = nav.mounted_screen() as LevelScreen
	assert_false(screen.completion_layer.visible)
	var observed: Array[bool] = []
	screen.controller.completed.connect(
		func() -> void:
			observed.append(
				int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]) == 2
			)
	)
	_content.requested.clear()
	_finish(screen)
	assert_eq(observed, [true])
	assert_true(screen.completion_layer.visible)
	assert_true(2 in _content.requested)
	assert_true(screen.hint_button.disabled)
	var writes: int = _storage.writes
	var button: PrimaryButton = screen.continue_button
	button.pressed.emit()
	assert_eq(nav.level_slot(), 2)
	assert_eq(
		(nav.mounted_screen() as LevelScreen).controller.get_board().get_level().get_slot(), 2
	)
	button.pressed.emit()
	assert_eq(nav.level_slot(), 2)
	assert_eq(_storage.writes, writes)


func test_failed_persistence_and_navigation_retry() -> void:
	var screen: LevelScreen = _scene()
	var nav: NavigationFailure = NavigationFailure.new()
	add_child_autofree(nav)
	screen.configure_navigation(nav)
	_storage.fail = true
	_finish(screen)
	assert_false(screen.completion_layer.visible)
	_storage.fail = false
	screen.hint_button.pressed.emit()
	assert_true(screen.completion_layer.visible)
	var writes: int = _storage.writes
	_content.unavailable = 2
	screen.continue_button.pressed.emit()
	assert_false(screen.continue_button.disabled)
	assert_eq(nav.calls, 0)
	assert_eq(screen.status_label.text, screen.tr("level.complete.retry"))
	_content.unavailable = 0
	screen.continue_button.pressed.emit()
	assert_eq(nav.calls, 1)
	assert_false(screen.continue_button.disabled)
	nav.error = OK
	screen.continue_button.pressed.emit()
	screen.continue_button.pressed.emit()
	assert_eq(nav.calls, 2)
	assert_true(screen.continue_button.disabled)
	assert_eq(_storage.writes, writes)


func test_terminal_content_resume_and_locale() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("pl")
	_slot(3)
	var screen: LevelScreen = _scene(3)
	_finish(screen)
	assert_true(screen.completion_layer.visible)
	assert_true(screen.continue_button.disabled)
	assert_eq(screen.completion_title.text, "Ukończono dostępne poziomy")
	assert_eq(screen.progress.current_slot(), 4)
	var writes: int = _storage.writes
	watch_signals(_bus)
	var resumed: LevelScreen = _scene(3)
	assert_true(resumed.controller.is_complete())
	assert_true(resumed.completion_layer.visible)
	assert_true(resumed.continue_button.disabled)
	assert_true(resumed.wheel.is_locked())
	assert_eq(resumed.board_view.cell_node(Vector2i.ZERO).state, GridCell.State.FILLED)
	assert_eq(_storage.writes, writes)
	assert_signal_not_emitted(_bus, "level_completed")
	var replay: LevelScreen = _scene(1)
	assert_false(replay.controller.is_complete())
	assert_false(replay.completion_layer.visible)
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(resumed.completion_title.text, "All available levels complete")
	assert_eq(resumed.continue_button.text, "Continue")
	TranslationServer.set_locale(previous_locale)


func test_completion_layout() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	var screen: LevelScreen = _new_scene()
	screen.configure(_save, _content, 1, _bus)
	screen.debug_insets = Rect2(16, 40, 24, 32)
	viewport.add_child(screen)
	_finish(screen)
	var expanded: Translation = Translation.new()
	expanded.locale = "en"
	expanded.add_message("level.complete.title", "Level complete — expanded completion title")
	expanded.add_message("level.complete.continue", "Continue to the next available level")
	TranslationServer.add_translation(expanded)
	var previous_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		viewport.size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		assert_gte(screen.continue_button.global_position.x, float(Tokens.Space.M + 16))
		assert_lte(
			screen.continue_button.get_global_rect().end.x,
			dimensions.x - Tokens.Space.M - 24 + 0.001
		)
		assert_lte(
			screen.completion_layer.get_global_rect().end.y, screen.board_view.global_position.y
		)
		assert_gte(screen.completion_layer.global_position.y, float(Tokens.Space.M + 40))
		assert_lte(
			screen.continue_button.get_global_rect().end.y,
			dimensions.y - Tokens.Space.M - 32 + 0.001
		)
		assert_gte(screen.continue_button.size.y, float(Tokens.Touch.MIN_TARGET))
		assert_gte(
			screen.continue_button.size.x, screen.continue_button.get_combined_minimum_size().x
		)
		assert_true(screen.board_view.fits_minimum())
	TranslationServer.remove_translation(expanded)
	TranslationServer.set_locale(previous_locale)
