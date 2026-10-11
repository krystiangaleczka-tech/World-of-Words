extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const NAV_SCRIPT: Script = preload("res://services/nav.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _storage: MemoryStorage
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _nav: NAV_SCRIPT
var _reduced_motion: bool


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-11T12:00:00Z", "0.1.0"
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
	_reduced_motion = Tokens.reduced_motion
	_storage = MemoryStorage.new()
	_save = SAVE_SCRIPT.new()
	_content = CONTENT_SCRIPT.new()
	_nav = NAV_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var host: Control = Control.new()
	for node: Node in [_save, _content, _nav, config, host]:
		add_child_autofree(node)
	_save.initialize(Clock.new())
	_save.configure(_storage)
	_nav.configure(_save, config, _content)
	assert_eq(_nav.start(host, "res://tests/fixtures/content"), OK)


func after_each() -> void:
	Tokens.reduced_motion = _reduced_motion
	await get_tree().process_frame


func _open_second_slot() -> LevelScreen:
	assert_eq(_nav.go_to_level(2), OK)
	assert_eq(_nav.go_debug(), OK)
	var debug: Node = _nav.mounted_screen()
	assert_eq(debug.selected_slot(), 2)
	assert_eq(debug.open_selected(), OK)
	return _nav.mounted_screen() as LevelScreen


func _attempt(screen: LevelScreen, tiles: PackedInt32Array) -> void:
	screen.wheel.pointer_begin(0, screen.wheel.tile_position(tiles[0]))
	for index: int in range(1, tiles.size()):
		screen.wheel.pointer_move(0, screen.wheel.tile_position(tiles[index]))
	screen.wheel.pointer_end(0)


func test_earlier_slot_shuffle_return_words_hints_and_completion_preserve_save() -> void:
	var section: Dictionary = _save.get_section(&"progress")
	var active: BoardState = BoardState.new(_content.level_for_slot(3))
	active.evaluate(PackedInt32Array([3, 1, 2, 4]))
	section["by_lang"]["pl"] = SaveSchema.LANGUAGE_STATE.duplicate(true)
	section["by_lang"]["pl"]["current_slot"] = 3
	section["by_lang"]["pl"]["highest_completed_slot"] = 2
	section["by_lang"]["pl"]["completed_slot"] = 2
	section["by_lang"]["pl"]["level_state"] = active.to_dict()
	assert_eq(_save.set_section(&"progress", section), OK)
	assert_eq(_save.flush(), OK)
	var original: Dictionary = _storage.document.duplicate(true)
	var writes: int = _storage.writes
	var screen: LevelScreen = _open_second_slot()
	Tokens.reduced_motion = true
	for _index: int in 3:
		screen.shuffle_button.pressed.emit()
	assert_eq(_nav.go_debug(), OK)
	assert_eq(_nav.mounted_screen().open_selected(), OK)
	screen = _nav.mounted_screen() as LevelScreen
	watch_signals(screen.controller)
	_attempt(screen, PackedInt32Array([0, 1, 2]))
	assert_signal_emitted(screen.controller, "result_ready")
	assert_eq(screen.preview.feedback_kind(), AttemptResult.Kind.LEVEL)
	assert_eq(screen.board_view.cell_node(Vector2i.ZERO).state, GridCell.State.FILLED)
	_attempt(screen, PackedInt32Array([0, 3, 2]))
	assert_eq(screen.preview.feedback_kind(), AttemptResult.Kind.BONUS)
	assert_eq(screen.controller.get_board().bonus_words(), PackedStringArray(["DAM"]))
	_attempt(screen, PackedInt32Array([0, 1, 2]))
	assert_eq(screen.preview.feedback_kind(), AttemptResult.Kind.ALREADY_FOUND)
	assert_true(screen.controller.hint())
	_attempt(screen, PackedInt32Array([2, 1, 0, 3]))
	assert_true(screen.completion_layer.visible)
	assert_signal_not_emitted(screen.controller, "persistence_failed")
	screen.progress.notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_storage.writes, writes)
	assert_eq_deep(_storage.document, original)
	assert_eq_deep(_save.get_section(&"progress"), section)
	assert_eq(_nav.go_debug(), OK)
	assert_eq(_nav.mounted_screen().open_selected(), OK)
	screen = _nav.mounted_screen() as LevelScreen
	assert_true(screen.controller.get_board().found_words().is_empty())
	assert_true(screen.controller.get_board().bonus_words().is_empty())
	assert_eq(_storage.writes, writes)
	assert_eq_deep(_storage.document, original)


func test_future_slot_can_be_completed_without_advancing_campaign() -> void:
	var original: Dictionary = _storage.document.duplicate(true)
	var writes: int = _storage.writes
	var screen: LevelScreen = _open_second_slot()
	_attempt(screen, PackedInt32Array([0, 1, 2]))
	_attempt(screen, PackedInt32Array([2, 1, 0, 3]))
	assert_true(screen.completion_layer.visible)
	assert_eq(_storage.writes, writes)
	assert_eq_deep(_storage.document, original)
	assert_eq(screen.progress.current_slot(), 1)


func test_current_slot_still_requires_durable_save_and_retry() -> void:
	assert_eq(_nav.go_to_level(1), OK)
	var screen: LevelScreen = _nav.mounted_screen() as LevelScreen
	watch_signals(screen.controller)
	_storage.fail = true
	assert_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_signal_emitted(screen.controller, "persistence_failed")
	assert_signal_not_emitted(screen.controller, "result_ready")
	assert_false(screen.completion_layer.visible)
	_storage.fail = false
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_true(screen.completion_layer.visible)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 2)


func test_busy_configure_cannot_switch_mode_and_idle_configure_defaults_to_persistence() -> void:
	var controller: LevelController = LevelController.new()
	var bus: Node = EVENTS_SCRIPT.new()
	add_child_autofree(controller)
	add_child_autofree(bus)
	var board: BoardState = BoardState.new(_content.level_for_slot(2))
	assert_true(controller.configure(board, null, bus, false))
	var handler: Callable = func(_result: AttemptResult) -> void:
		assert_false(controller.configure(board, null, bus))
	controller.result_ready.connect(handler)
	assert_not_null(controller.submit(PackedInt32Array([0, 1, 2])))
	controller.result_ready.disconnect(handler)
	assert_not_null(controller.submit(PackedInt32Array([0, 3, 2])))
	assert_true(controller.configure(BoardState.new(_content.level_for_slot(2)), null, bus))
	watch_signals(controller)
	assert_null(controller.submit(PackedInt32Array([0, 1, 2])))
	assert_signal_emitted_with_parameters(controller, "persistence_failed", [ERR_UNCONFIGURED])
