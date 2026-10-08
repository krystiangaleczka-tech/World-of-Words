extends GutTest

const EVENTS_SCRIPT: Script = preload("res://services/events.gd")


class ProgressSpy:
	extends "res://services/progress.gd"
	var writes: int = 0

	func save_level(_board: BoardState) -> Error:
		writes += 1
		return OK

	func complete_level(_slot: int) -> Error:
		writes += 1
		return OK


func _board() -> BoardState:
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	return BoardState.new(LevelData.from_dict(pack["levels"][0]))


func _watch(controller: LevelController, bus: Node) -> void:
	watch_signals(controller)
	watch_signals(bus)


func _assert_silent(controller: LevelController, bus: Node) -> void:
	for name: String in ["result_ready", "state_changed", "completed", "persistence_failed"]:
		assert_signal_not_emitted(controller, name)
	for name: String in [
		"word_found", "bonus_found", "already_found", "invalid_word", "hint_used", "level_completed"
	]:
		assert_signal_not_emitted(bus, name)


func test_configure_board_and_ignored_attempt_contract() -> void:
	var controller: LevelController = LevelController.new()
	add_child_autofree(controller)
	var progress: ProgressSpy = ProgressSpy.new()
	add_child_autofree(progress)
	var bus: Node = EVENTS_SCRIPT.new()
	add_child_autofree(bus)
	_watch(controller, bus)
	assert_null(controller.get_board())
	assert_false(controller.is_complete())
	assert_false(controller.hint(), "An unconfigured controller cannot reveal a hint")
	assert_null(controller.submit(PackedInt32Array()))
	var board: BoardState = _board()
	var snapshot: Dictionary = board.to_dict()
	controller.configure(board, progress, bus)
	assert_same(controller.get_board(), board)
	assert_false(controller.is_complete())
	for tiles: PackedInt32Array in [
		PackedInt32Array(),
		PackedInt32Array([0]),
		PackedInt32Array([0, 1]),
		PackedInt32Array([-1, 99])
	]:
		assert_null(controller.submit(tiles))
		assert_eq_deep(board.to_dict(), snapshot)
	_assert_silent(controller, bus)
	assert_eq(progress.writes, 0)
	board.evaluate(PackedInt32Array([0, 1, 2]))
	assert_true(controller.is_complete(), "Completion reads the live injected board")
	assert_null(controller.submit(PackedInt32Array([0, 1])))
	_assert_silent(controller, bus)
	assert_eq(progress.writes, 0)


func test_reconfiguration_replaces_dependencies_without_effects() -> void:
	var controller: LevelController = LevelController.new()
	add_child_autofree(controller)
	var first_progress: ProgressSpy = ProgressSpy.new()
	var second_progress: ProgressSpy = ProgressSpy.new()
	add_child_autofree(first_progress)
	add_child_autofree(second_progress)
	var first_bus: Node = EVENTS_SCRIPT.new()
	var second_bus: Node = EVENTS_SCRIPT.new()
	add_child_autofree(first_bus)
	add_child_autofree(second_bus)
	_watch(controller, first_bus)
	watch_signals(second_bus)
	var first: BoardState = _board()
	var second: BoardState = _board()
	controller.configure(first, first_progress, first_bus)
	controller.configure(second, second_progress, second_bus)
	first.evaluate(PackedInt32Array([0, 1, 2]))
	assert_same(controller.get_board(), second)
	assert_false(controller.is_complete())
	assert_null(controller.submit(PackedInt32Array([0])))
	assert_eq(first_progress.writes, 0)
	assert_eq(second_progress.writes, 0)
	_assert_silent(controller, first_bus)
	_assert_silent(controller, second_bus)
