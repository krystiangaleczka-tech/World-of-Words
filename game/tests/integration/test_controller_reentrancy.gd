extends GutTest

const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _controller: LevelController
var _progress: ProgressSpy
var _bus: EVENTS_SCRIPT
var _board: BoardState
var _replacement: BoardState
var _checks: int = 0


class ProgressSpy:
	extends "res://services/progress.gd"
	var writes: int = 0
	var failure: Error = OK

	func save_level(_board: BoardState) -> Error:
		writes += 1
		return failure

	func complete_level(_slot: int) -> Error:
		writes += 1
		return failure


func _new_board() -> BoardState:
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	return BoardState.new(LevelData.from_dict(pack["levels"][0]))


func before_each() -> void:
	_checks = 0
	_controller = LevelController.new()
	_progress = ProgressSpy.new()
	_bus = EVENTS_SCRIPT.new()
	add_child_autofree(_controller)
	add_child_autofree(_progress)
	add_child_autofree(_bus)
	_board = _new_board()
	_replacement = _new_board()
	assert_true(_controller.configure(_board, _progress, _bus))
	watch_signals(_controller)
	watch_signals(_bus)


func _try_reentry() -> void:
	_checks += 1
	var snapshot: Dictionary = _board.to_dict()
	var writes: int = _progress.writes
	assert_false(_controller.configure(_replacement, _progress, _bus))
	assert_null(_controller.submit(PackedInt32Array([0, 1, 2])))
	assert_false(_controller.hint())
	assert_same(_controller.get_board(), _board)
	assert_eq_deep(_board.to_dict(), snapshot)
	assert_eq(_progress.writes, writes)
	assert_true(_replacement.revealed_cells().is_empty())


func _result_callback(_result: AttemptResult) -> void:
	_try_reentry()


func _error_callback(_error: Error) -> void:
	_try_reentry()


func _word_callback(_word: String) -> void:
	_try_reentry()


func _slot_callback(_slot: int) -> void:
	_try_reentry()


func test_invalid_publication_rejects_nested_actions_and_configuration() -> void:
	_controller.result_ready.connect(_result_callback)
	_bus.invalid_word.connect(_word_callback)
	var snapshot: Dictionary = _board.to_dict()
	var result: AttemptResult = _controller.submit(PackedInt32Array([0, 0, 2]))
	_controller.result_ready.disconnect(_result_callback)
	_bus.invalid_word.disconnect(_word_callback)
	assert_not_null(result)
	if result != null:
		assert_eq(result.kind, AttemptResult.Kind.INVALID)
	assert_eq(_checks, 2)
	assert_eq(_progress.writes, 0)
	assert_eq_deep(_board.to_dict(), snapshot)
	assert_signal_emit_count(_bus, "invalid_word", 1)
	assert_signal_not_emitted(_bus, "word_found")
	assert_signal_not_emitted(_controller, "state_changed")
	assert_true(_controller.configure(_replacement, _progress, _bus))
	assert_true(_controller.hint(), "The guard is released after a nonmutating result")
	assert_eq(_progress.writes, 1)


func test_already_found_publication_preserves_credited_bonus() -> void:
	var tiles: PackedInt32Array = PackedInt32Array([2, 1, 0])
	assert_eq(_controller.submit(tiles).kind, AttemptResult.Kind.BONUS)
	_controller.result_ready.connect(_result_callback)
	_bus.already_found.connect(_word_callback)
	var result: AttemptResult = _controller.submit(tiles)
	_controller.result_ready.disconnect(_result_callback)
	_bus.already_found.disconnect(_word_callback)
	assert_eq(result.kind, AttemptResult.Kind.ALREADY_FOUND)
	assert_eq(_checks, 2)
	assert_eq(_progress.writes, 1)
	assert_eq(_board.bonus_words(), PackedStringArray(["TOK"]))
	assert_signal_emit_count(_bus, "bonus_found", 1)
	assert_signal_emit_count(_bus, "already_found", 1)
	assert_true(_controller.configure(_replacement, _progress, _bus))


func test_completion_guards_mutation_persistence_and_all_publications() -> void:
	_board.completed.connect(_try_reentry)
	_controller.state_changed.connect(_try_reentry)
	_controller.result_ready.connect(_result_callback)
	_controller.completed.connect(_try_reentry)
	_bus.level_completed.connect(_slot_callback)
	_bus.word_found.connect(_word_callback)
	var result: AttemptResult = _controller.submit(PackedInt32Array([0, 1, 2]))
	_board.completed.disconnect(_try_reentry)
	_controller.state_changed.disconnect(_try_reentry)
	_controller.result_ready.disconnect(_result_callback)
	_controller.completed.disconnect(_try_reentry)
	_bus.level_completed.disconnect(_slot_callback)
	_bus.word_found.disconnect(_word_callback)
	assert_not_null(result)
	assert_eq(_checks, 6)
	assert_eq(_progress.writes, 1)
	assert_true(_board.is_complete())
	assert_same(_controller.get_board(), _board)
	assert_signal_emitted_with_parameters(_bus, "level_completed", [1])
	assert_signal_emitted_with_parameters(_bus, "word_found", ["KOT"])
	assert_signal_emit_count(_controller, "completed", 1)
	assert_true(_controller.configure(_replacement, _progress, _bus))
	assert_eq(_controller.submit(PackedInt32Array([0, 1, 2])).kind, AttemptResult.Kind.LEVEL)
	assert_eq(_progress.writes, 2)


func test_failure_callback_keeps_pending_retry_and_releases_guard() -> void:
	_progress.failure = ERR_BUSY
	_controller.persistence_failed.connect(_error_callback)
	assert_null(_controller.submit(PackedInt32Array([0, 1, 2])))
	_controller.persistence_failed.disconnect(_error_callback)
	assert_eq(_checks, 1)
	assert_true(_board.is_complete(), "P1 failed mutation remains pending, not rolled back")
	assert_signal_not_emitted(_controller, "completed")
	assert_signal_not_emitted(_bus, "word_found")
	_progress.failure = OK
	assert_not_null(_controller.submit(PackedInt32Array([0, 1, 2])))
	assert_eq(_progress.writes, 2)
	assert_signal_emit_count(_controller, "state_changed", 1)
	assert_signal_emit_count(_controller, "completed", 1)
	assert_signal_emit_count(_bus, "level_completed", 1)
	assert_signal_emit_count(_bus, "word_found", 1)
	assert_false(_controller.hint(), "An ignored reveal also releases the guard")
	assert_true(_controller.configure(_replacement, _progress, _bus))
