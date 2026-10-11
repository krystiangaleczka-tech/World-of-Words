extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const NAV_SCRIPT: Script = preload("res://services/nav.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")
const CURRENT_SLOT: int = 33

var _storage: MemoryStorage
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _nav: NAV_SCRIPT
var _reduced_motion: bool


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1791720000

	func monotonic_msec() -> int:
		return 0

	func monotonic_usec() -> int:
		return 0


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
	Tokens.reduced_motion = true
	_storage = MemoryStorage.new()
	_save = SAVE_SCRIPT.new()
	_content = CONTENT_SCRIPT.new()
	_nav = NAV_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var host: Control = Control.new()
	for node: Node in [_save, _content, _nav, config, host]:
		add_child_autofree(node)
	_save.initialize(FixedClock.new())
	_save.configure(_storage)
	_nav.configure(_save, config, _content)
	assert_eq(_nav.start(host), OK)
	assert_eq(_content.slot_count(), 65)


func after_each() -> void:
	Tokens.reduced_motion = _reduced_motion
	await get_tree().process_frame


func _campaign(slot: int, partial: bool = false) -> Dictionary:
	var section: Dictionary = _save.get_section(&"progress")
	var state: Dictionary = SaveSchema.LANGUAGE_STATE.duplicate(true)
	state["current_slot"] = slot
	state["highest_completed_slot"] = slot - 1
	state["completed_slot"] = slot - 1
	if partial:
		var level: LevelData = _content.level_for_slot(slot)
		var board: BoardState = BoardState.new(level)
		board.evaluate(_tiles(level, level.word(0)))
		assert_false(board.is_complete())
		state["level_state"] = board.to_dict()
	section["by_lang"]["pl"] = state
	assert_eq(_save.set_section(&"progress", section), OK)
	assert_eq(_save.flush(), OK)
	return _save.get_section(&"progress")


func _diagnostic(slot: int) -> LevelScreen:
	assert_eq(_nav.go_to_level(slot), OK)
	assert_eq(_nav.go_debug(), OK)
	var debug: Node = _nav.mounted_screen()
	assert_eq(debug.selected_slot(), slot)
	assert_eq(debug.open_selected(), OK)
	await get_tree().process_frame
	var screen: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_eq(screen.controller.get_board().get_level().get_slot(), slot)
	return screen


func _tiles(level: LevelData, word: String) -> PackedInt32Array:
	var tiles: PackedInt32Array = PackedInt32Array()
	for letter: String in word:
		for tile: int in level.tile_count():
			if level.tile_letter(tile) == letter and not tiles.has(tile):
				tiles.append(tile)
				break
	assert_eq(level.spell(tiles), word)
	return tiles


func _swipe(screen: LevelScreen, word: String) -> void:
	var tiles: PackedInt32Array = _tiles(screen.controller.get_board().get_level(), word)
	screen.wheel.pointer_begin(0, screen.wheel.tile_position(tiles[0]))
	for index: int in range(1, tiles.size()):
		screen.wheel.pointer_move(0, screen.wheel.tile_position(tiles[index]))
	screen.wheel.pointer_end(0)


func _solve(screen: LevelScreen) -> void:
	var board: BoardState = screen.controller.get_board()
	var level: LevelData = board.get_level()
	for index: int in level.word_count():
		var word: String = level.word(index)
		if word not in board.found_words():
			_swipe(screen, word)
			assert_eq(screen.preview.feedback_kind(), AttemptResult.Kind.LEVEL, level.get_id())
		assert_true(word in board.found_words(), level.get_id() + " " + word)
		for cell: Vector2i in level.word_cells(index):
			assert_eq(screen.board_view.cell_node(cell).state, GridCell.State.FILLED)
	assert_true(board.is_complete(), level.get_id())
	assert_true(screen.completion_layer.visible, level.get_id())
	assert_true(screen.wheel.is_locked(), level.get_id())


func test_all_noncurrent_shipped_slots_preserve_partial_campaign() -> void:
	var progress: Dictionary = _campaign(CURRENT_SLOT, true)
	var original: Dictionary = _storage.document.duplicate(true)
	var writes: int = _storage.writes
	for slot: int in range(1, _content.slot_count() + 1):
		if slot == CURRENT_SLOT:
			continue
		var screen: LevelScreen = await _diagnostic(slot)
		for _shuffle: int in 3:
			screen.shuffle_button.pressed.emit()
		assert_eq(_nav.go_debug(), OK)
		assert_eq(_nav.mounted_screen().open_selected(), OK)
		await get_tree().process_frame
		screen = _nav.mounted_screen() as LevelScreen
		for _shuffle: int in 3:
			screen.shuffle_button.pressed.emit()
		var bonuses: PackedStringArray = screen.controller.get_board().get_level().bonus_words()
		if not bonuses.is_empty():
			_swipe(screen, bonuses[0])
			assert_eq(screen.preview.feedback_kind(), AttemptResult.Kind.BONUS)
			assert_eq(screen.controller.get_board().bonus_words(), PackedStringArray([bonuses[0]]))
		_solve(screen)
		screen.progress.notification(NOTIFICATION_APPLICATION_PAUSED)
		assert_eq(_storage.writes, writes, "diagnostic slot %d must not write" % slot)
		assert_eq_deep(_storage.document, original)
		assert_eq_deep(_save.get_section(&"progress"), progress)
		assert_eq(_nav.go_debug(), OK)
		assert_eq(_nav.mounted_screen().open_selected(), OK)
		await get_tree().process_frame
		screen = _nav.mounted_screen() as LevelScreen
		assert_false(screen.completion_layer.visible)
		assert_true(screen.controller.get_board().found_words().is_empty())
		assert_true(screen.controller.get_board().bonus_words().is_empty())
		assert_eq(_storage.writes, writes)
	var reloaded: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(reloaded)
	reloaded.initialize(FixedClock.new())
	reloaded.configure(_storage)
	assert_eq(reloaded.load(), OK)
	var restored: PROGRESS_SCRIPT = PROGRESS_SCRIPT.new()
	add_child_autofree(restored)
	restored.configure(reloaded, _content)
	assert_eq(restored.current_slot(), CURRENT_SLOT)
	assert_eq_deep(
		restored.restore_level(_content.level_for_slot(CURRENT_SLOT)).to_dict(),
		progress["by_lang"]["pl"]["level_state"]
	)


func test_current_shipped_slot_retries_before_results_and_continues_once() -> void:
	_campaign(CURRENT_SLOT)
	assert_eq(_nav.go_to_level(CURRENT_SLOT), OK)
	await get_tree().process_frame
	var screen: LevelScreen = _nav.mounted_screen() as LevelScreen
	var level: LevelData = screen.controller.get_board().get_level()
	var original: Dictionary = _storage.document.duplicate(true)
	var durable: Array[bool] = []
	screen.controller.result_ready.connect(
		func(result: AttemptResult) -> void:
			var state: Dictionary = _storage.document["progress"]["by_lang"]["pl"]
			durable.append(
				(
					int(state["current_slot"]) == CURRENT_SLOT + 1
					or result.word in state["level_state"].get("found_words", [])
				)
			)
	)
	watch_signals(screen.controller)
	_storage.fail = true
	_swipe(screen, level.word(0))
	assert_signal_emitted(screen.controller, "persistence_failed")
	assert_signal_not_emitted(screen.controller, "result_ready")
	assert_signal_not_emitted(screen.controller, "completed")
	assert_eq_deep(_storage.document, original)
	assert_false(screen.completion_layer.visible)
	_storage.fail = false
	_swipe(screen, level.word(0))
	assert_eq(durable, [true])
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), CURRENT_SLOT)
	_solve(screen)
	assert_true(durable.all(func(value: bool) -> bool: return value))
	assert_signal_emit_count(screen.controller, "completed", 1)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), CURRENT_SLOT + 1)
	var writes: int = _storage.writes
	var button: PrimaryButton = screen.continue_button
	button.pressed.emit()
	button.pressed.emit()
	assert_eq(_nav.level_slot(), CURRENT_SLOT + 1)
	assert_eq(_storage.writes, writes)
	assert_false((_nav.mounted_screen() as LevelScreen).controller.is_complete())


func test_completed_shipped_campaign_keeps_terminal_resume_and_early_replay_isolated() -> void:
	_campaign(_content.slot_count() + 1)
	var original: Dictionary = _storage.document.duplicate(true)
	var writes: int = _storage.writes
	var terminal: LevelScreen = await _diagnostic(_content.slot_count())
	assert_true(terminal.controller.is_complete())
	assert_true(terminal.completion_layer.visible)
	assert_true(terminal.continue_button.disabled)
	assert_true(terminal.wheel.is_locked())
	assert_eq(_storage.writes, writes)
	var early: LevelScreen = await _diagnostic(7)
	_swipe(early, "KUR")
	assert_eq(early.preview.feedback_kind(), AttemptResult.Kind.BONUS)
	_solve(early)
	early.progress.notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_eq_deep(_storage.document, original)
	assert_eq(_storage.writes, writes)
	terminal = await _diagnostic(_content.slot_count())
	assert_true(terminal.controller.is_complete())
	assert_true(terminal.continue_button.disabled)
	assert_eq_deep(_storage.document, original)
	assert_eq(_storage.writes, writes)
