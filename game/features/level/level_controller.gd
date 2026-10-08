class_name LevelController
extends Node
## @api Per-level orchestration boundary. Views consume signals; services own persistence.

signal result_ready(result: AttemptResult)
signal state_changed
signal completed
signal persistence_failed(error: Error)

const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")

var _board: BoardState
var _progress: PROGRESS_SCRIPT
var _event_bus: Node
var _pending: bool = false
var _pending_result: AttemptResult
var _pending_hint: bool = false
var _announced_complete: bool = false
var _busy: bool = false


## @api Inject one active board, its progress service and the side-effect bus.
## Reconfiguration replaces references without gameplay, persistence or signal side effects.
func configure(board: BoardState, progress: PROGRESS_SCRIPT, event_bus: Node) -> void:
	_board = board
	_progress = progress
	_event_bus = event_bus
	_pending = false
	_pending_result = null
	_pending_hint = false
	_announced_complete = false


## @api The active board, or null before configuration.
func get_board() -> BoardState:
	return _board


## @api Short attempts are ignored without mutation, result or effects.
## An explicit action retries pending durability before accepting another mutation.
func submit(tiles: PackedInt32Array) -> AttemptResult:
	if tiles.size() < LevelData.MIN_TILES or _board == null or _busy:
		return null
	if _pending:
		var retry: AttemptResult = _pending_result
		return retry if _commit() else null
	if is_complete():
		return null
	var result: AttemptResult = _board.evaluate(tiles)
	if result.kind in [AttemptResult.Kind.LEVEL, AttemptResult.Kind.BONUS]:
		_pending = true
		_pending_result = result
		return result if _commit() else null
	_publish(result, false)
	return result


## @api Reveal one deterministic free hint, persisting before signals or effects.
func hint() -> bool:
	if _board == null or _busy:
		return false
	if _pending:
		return _commit()
	var cell: Vector2i = HintLogic.next_cell(_board)
	if not _board.reveal_cell(cell):
		return false
	_pending = true
	_pending_hint = true
	return _commit()


func _commit() -> bool:
	_busy = true
	var error: Error = ERR_UNCONFIGURED
	if is_instance_valid(_progress):
		error = (
			_progress.complete_level(_board.get_level().get_slot())
			if is_complete()
			else _progress.save_level(_board)
		)
	if error != OK:
		persistence_failed.emit(error)
		_busy = false
		return false
	var result: AttemptResult = _pending_result
	var was_hint: bool = _pending_hint
	_pending = false
	_pending_result = null
	_pending_hint = false
	state_changed.emit()
	_publish(result, was_hint)
	_busy = false
	return true


func _publish(result: AttemptResult, was_hint: bool) -> void:
	if result != null:
		result_ready.emit(result)
	if is_complete() and not _announced_complete:
		_announced_complete = true
		completed.emit()
		_effect(&"level_completed", _board.get_level().get_slot())
	if was_hint:
		_effect(&"hint_used")
	if result == null:
		return
	var names: Array[StringName] = [
		&"word_found", &"bonus_found", &"already_found", &"invalid_word"
	]
	_effect(names[result.kind], result.word)


func _effect(name: StringName, argument: Variant = null) -> void:
	if not is_instance_valid(_event_bus) or not _event_bus.has_signal(name):
		return
	if argument == null:
		_event_bus.emit_signal(name)
	else:
		_event_bus.emit_signal(name, argument)


## @api Read live board completion; an unconfigured controller is incomplete.
func is_complete() -> bool:
	return _board != null and _board.is_complete()
