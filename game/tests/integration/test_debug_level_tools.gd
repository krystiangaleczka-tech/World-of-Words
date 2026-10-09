extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const NAV_SCRIPT: Script = preload("res://services/nav.gd")
const DEBUG_SCENE: PackedScene = preload("res://features/debug/debug.tscn")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _storage: MemoryStorage
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _bus: Node
var _nav: NAV_SCRIPT
var _config: CONFIG_SCRIPT
var _host: Control
var _locale: String


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var fail: bool = false
	var writes: int = 0
	var fail_from: int = 0

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		writes += 1
		if fail or (fail_from > 0 and writes >= fail_from):
			return ERR_FILE_CANT_WRITE
		document = JSON.parse_string(text)
		return OK


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("pl")
	_storage = MemoryStorage.new()
	_save = SAVE_SCRIPT.new()
	_content = CONTENT_SCRIPT.new()
	_bus = EVENTS_SCRIPT.new()
	add_child_autofree(_save)
	add_child_autofree(_content)
	add_child_autofree(_bus)
	_save.initialize(Clock.new())
	_save.configure(_storage)
	assert_eq(_save.load(), OK)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)

	_config = CONFIG_SCRIPT.new()
	_nav = NAV_SCRIPT.new()
	_host = Control.new()
	add_child_autofree(_config)
	add_child_autofree(_nav)
	add_child_autofree(_host)
	_nav.configure(_save, _config, _content)
	assert_eq(_nav.start(_host, "res://tests/fixtures/content"), OK)
	assert_eq(_nav.go_debug(), OK)


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _debug() -> Node:
	return _nav.mounted_screen()


func test_selection_answers_and_open() -> void:
	var screen: Node = _debug()
	var writes: int = _storage.writes
	assert_eq(screen.selected_slot(), 1)
	assert_true((screen.get_node("Safe/Body/SlotSelector/Previous") as TextButton).disabled)
	screen.select_previous()
	assert_eq(screen.selected_slot(), 1)
	screen.select_next()
	screen.select_next()
	screen.select_next()
	assert_eq(screen.selected_slot(), 3)
	assert_true((screen.get_node("Safe/Body/SlotSelector/Next") as TextButton).disabled)
	screen.select_previous()
	screen.toggle_answers()
	var answers: Label = screen.get_node("Safe/Body/Answers") as Label
	assert_true(answers.visible)
	assert_true(answers.text.contains("DOM"))
	assert_true(answers.text.contains("MODA"))
	assert_eq(_storage.writes, writes)
	screen.select_previous()
	assert_false(answers.visible)
	assert_eq(screen.open_selected(), OK)
	assert_eq(_nav.level_slot(), 1)
	assert_eq(_storage.writes, writes)


func test_complete_selected_and_preserve_other_sections() -> void:
	var screen: Node = _debug()
	var economy: Dictionary = _save.get_section(&"economy")
	var settings: Dictionary = _save.get_section(&"settings")
	var other: Dictionary = _save.get_section(&"progress")["by_lang"].get("en", {}).duplicate(true)
	screen.select_next()
	assert_eq(screen.complete_selected(), OK)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_true(level.controller.is_complete())
	assert_true(level.completion_layer.visible)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 3)
	assert_eq(_save.get_section(&"economy"), economy)
	assert_eq(_save.get_section(&"settings"), settings)
	assert_eq(_save.get_section(&"progress")["by_lang"].get("en", {}), other)
	assert_eq(_nav.go_debug(), OK)
	screen = _debug()
	screen.select_previous()
	assert_eq(screen.complete_selected(), OK)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 3)


func test_completion_storage_failure_and_missing_content() -> void:
	var screen: Node = _debug()
	screen.select_next()
	_storage.fail = true
	assert_eq(screen.complete_selected(), ERR_FILE_CANT_WRITE)
	assert_same(_nav.mounted_screen(), screen)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 1)
	assert_eq((screen.get_node("Safe/Body/Status") as Label).text, screen.tr("debug.level.error"))
	_storage.fail = false
	assert_eq(screen.complete_selected(), OK)
	assert_true((_nav.mounted_screen() as LevelScreen).controller.is_complete())
	var empty_content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	add_child_autofree(empty_content)
	var empty: Node = DEBUG_SCENE.instantiate()
	empty.configure(_save, empty_content, _nav)
	add_child_autofree(empty)
	assert_eq(empty.selected_slot(), 0)
	assert_true((empty.get_node("Safe/Body/OpenLevel") as TextButton).disabled)
	assert_eq(empty.complete_selected(), ERR_FILE_NOT_FOUND)
	empty.toggle_answers()
	assert_false((empty.get_node("Safe/Body/Answers") as Label).visible)


func test_locale_and_layout() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	var screen: Control = DEBUG_SCENE.instantiate() as Control
	screen.configure(_save, _content, _nav)
	screen.debug_insets = Rect2(16, 40, 24, 32)
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	for node: Node in screen.get_node("Safe/Body").get_children():
		var control: Control = node as Control
		if control.visible:
			assert_gte(control.global_position.x, float(Tokens.Space.M + 16))
			assert_lte(control.get_global_rect().end.y, 1920.0 - Tokens.Space.M - 32)
	screen.toggle_answers()
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq((screen.get_node("Safe/Body/SlotSelector/SelectedSlot") as Label).text, "Level: 1")
	assert_true((screen.get_node("Safe/Body/Answers") as Label).text.begins_with("Show answers:"))
	assert_eq((screen.get_node("Safe/Body/OpenLevel") as TextButton).text, "Open level")


class BrokenContent:
	extends "res://services/content.gd"

	func level_for_slot(_slot_number: int) -> LevelData:
		pack_failed.emit("packs/broken.json", ERR_PARSE_ERROR)
		return null


func test_failed_override_then_changed_selection_and_controller_retry() -> void:
	var screen: Node = _debug()
	var original: Dictionary = _save.get_section(&"progress")
	screen.select_next()
	_storage.fail = true
	assert_eq(screen.complete_selected(), ERR_FILE_CANT_WRITE)
	assert_eq_deep(_save.get_section(&"progress"), original)
	_storage.fail = false
	screen.select_previous()
	assert_eq(screen.complete_selected(), OK)
	assert_true((_nav.mounted_screen() as LevelScreen).controller.is_complete())
	assert_eq(_nav.go_debug(), OK)
	screen = _debug()
	screen.select_next()
	_storage.fail_from = _storage.writes + 2
	assert_eq(screen.complete_selected(), ERR_FILE_CANT_WRITE)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_not_null(level)
	assert_true(level.status_label.visible)
	assert_false(level.completion_layer.visible)
	var revealed: int = level.controller.get_board().revealed_cells().size()
	_storage.fail_from = 0
	level.hint_button.pressed.emit()
	assert_eq(level.controller.get_board().revealed_cells().size(), revealed)
	for _index: int in 12:
		if not level.controller.is_complete():
			level.hint_button.pressed.emit()
	assert_true(level.completion_layer.visible)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 3)


func test_broken_pack_and_earlier_uncompleted_slot_rejected() -> void:
	var broken: BrokenContent = BrokenContent.new()
	add_child_autofree(broken)
	assert_eq(broken.load_manifest("pl", "res://tests/fixtures/content"), OK)
	var screen: Node = DEBUG_SCENE.instantiate()
	screen.configure(_save, broken, _nav)
	add_child_autofree(screen)
	watch_signals(broken)
	var writes: int = _storage.writes
	screen.toggle_answers()
	assert_signal_emitted(broken, "pack_failed")
	assert_false((screen.get_node("Safe/Body/Answers") as Label).visible)
	assert_eq(screen.complete_selected(), ERR_FILE_NOT_FOUND)
	assert_eq(_storage.writes, writes)
	var section: Dictionary = _save.get_section(&"progress")
	section["by_lang"]["pl"]["current_slot"] = 2
	assert_eq(_save.set_section(&"progress", section), OK)
	assert_eq(_save.flush(), OK)
	var normal: Node = _debug()
	writes = _storage.writes
	assert_eq(normal.complete_selected(), ERR_INVALID_PARAMETER)
	assert_same(_nav.mounted_screen(), normal)
	assert_eq(_storage.writes, writes)


func test_last_cell_failure_reports_error_until_durable_retry() -> void:
	var screen: Node = _debug()
	_storage.fail_from = _storage.writes + 3
	assert_eq(screen.complete_selected(), ERR_FILE_CANT_WRITE)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_true(level.controller.is_complete())
	assert_false(level.completion_layer.visible)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 1)
	_storage.fail_from = 0
	level.hint_button.pressed.emit()
	assert_true(level.completion_layer.visible)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 2)
