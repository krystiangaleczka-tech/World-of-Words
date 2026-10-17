class_name LevelController
extends Node
## @api Per-level orchestration boundary. Views consume signals; services own persistence.

signal player_word_committed
signal result_ready(result: AttemptResult)
signal state_changed
signal completed
signal persistence_failed(error: Error)
signal paid_tool_committed(kind: StringName, cells: Array[Vector2i])

const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")

var _board: BoardState
var _progress: PROGRESS_SCRIPT
var _event_bus: Node
var _pending: bool = false
var _pending_result: AttemptResult
var _pending_hint: bool = false
var _pending_player: bool = false
var _announced_complete: bool = false
var _busy: bool = false
var _persist_progress: bool = true
var _tool_port: AtomicProgressPort
var _tool_save: Node
var _tool_request: Dictionary = {}
var _paid_feedback: bool = false


## @api Inject one active board, its progress service and the side-effect bus.
## Idle reconfiguration returns true; an active action rejects it without changes.
## Diagnostic sessions may disable persistence without changing campaign Save.
func configure(
	board: BoardState, progress: PROGRESS_SCRIPT, event_bus: Node, persist_progress: bool = true
) -> bool:
	if _busy or paid_pending() or _paid_feedback or _tool_port != null:
		return false
	_tool_port = null
	_tool_save = null
	_board = board
	_progress = progress
	_event_bus = event_bus
	_persist_progress = persist_progress
	_pending = false
	_pending_result = null
	_pending_hint = false
	_pending_player = false
	_announced_complete = false
	return true


## @api The active board, or null before configuration.
func get_board() -> BoardState:
	return _board


## @api Short attempts are ignored without mutation, result or effects.
## An explicit action retries pending durability before accepting another mutation.
func submit(tiles: PackedInt32Array) -> AttemptResult:
	if (
		tiles.size() < LevelData.MIN_TILES
		or _board == null
		or _busy
		or paid_pending()
		or _paid_feedback
	):
		return null
	if _pending:
		var retry: AttemptResult = _pending_result
		return retry if _commit() else null
	if is_complete():
		return null
	_busy = true
	var result: AttemptResult = _board.evaluate(tiles)
	if result.kind in [AttemptResult.Kind.LEVEL, AttemptResult.Kind.BONUS]:
		_pending = true
		_pending_result = result
		_pending_player = true
		return result if _commit() else null
	_publish(result, false)
	_busy = false
	return result


## @api Reveal one deterministic free hint, persisting before signals or effects.
func hint() -> bool:
	if _tool_port != null:
		return use_paid_tool(&"hint").error == OK
	if _board == null or _busy:
		return false
	if _pending:
		return _commit()
	_busy = true
	var cell: Vector2i = HintLogic.next_cell(_board)
	if not _board.reveal_cell(cell):
		_busy = false
		return false
	_pending = true
	_pending_hint = true
	return _commit()


func _commit() -> bool:
	_busy = true
	var error: Error = OK if not _persist_progress else ERR_UNCONFIGURED
	if _persist_progress and is_instance_valid(_progress):
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
	var was_player: bool = _pending_player and _persist_progress
	_pending = false
	_pending_result = null
	_pending_hint = false
	_pending_player = false
	if was_player:
		player_word_committed.emit()
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


## @api Explicit paid activation; the normal free P1 controller remains unchanged.
func configure_paid_tools(save: Node, port: AtomicProgressPort) -> Error:
	if _busy or _pending or paid_pending() or _paid_feedback:
		return ERR_BUSY
	if (
		port == null
		or not is_instance_valid(_progress)
		or not _progress.p2_ready()
		or not port.certifies(save, _progress)
		or not port.is_available()
	):
		return ERR_UNCONFIGURED
	if (
		not _persist_progress
		or _board == null
		or _board.get_level().get_slot() != _progress.current_slot()
	):
		return ERR_UNCONFIGURED
	_tool_save = save
	_tool_port = port
	return OK


func paid_pending() -> bool:
	return not _tool_request.is_empty()


func paid_locked() -> bool:
	return _busy or paid_pending() or _paid_feedback


func paid_feedback_active() -> bool:
	return _paid_feedback


## @api Caller releases only presentation lock; unresolved durability cannot be released.
func release_paid_feedback() -> void:
	_paid_feedback = false


## @api One closed paid candidate; an unresolved request is retried without regeneration.
func use_paid_tool(kind: StringName) -> Dictionary:
	if _busy or _pending or _paid_feedback:
		return {"error": ERR_BUSY, "state": "busy"}
	if _tool_port == null or _board == null or kind not in [&"hint", &"reveal"]:
		return {"error": ERR_UNCONFIGURED, "state": "unavailable"}
	if paid_pending() and _tool_request.tool.kind != str(kind):
		return {"error": ERR_BUSY, "state": "pending"}
	_busy = true
	var result: Dictionary = _use_paid_tool(kind)
	_busy = false
	return result


func _use_paid_tool(kind: StringName) -> Dictionary:
	if not paid_pending():
		var candidate: BoardState = PaidToolPlan.after(_board, kind)
		if candidate == null:
			return {"error": ERR_UNAVAILABLE, "state": "unavailable"}
		var commands: Array[Dictionary] = _tool_port.tool_commands(kind, candidate.is_complete())
		if commands.is_empty():
			return {
				"error": ERR_UNAVAILABLE,
				"state":
				(
					"unaffordable"
					if _tool_port.is_available() and not _tool_save.writes_blocked()
					else "unavailable"
				)
			}
		_tool_request = _progress.paid_tool_request(_board, kind, commands)
		if _tool_request.is_empty():
			return {"error": ERR_UNAVAILABLE, "state": "unavailable"}
	var result: Dictionary = _tool_port.transact(_tool_request)
	if result.error != OK:
		if result.state == "rejected":
			_tool_request.clear()
		persistence_failed.emit(result.error)
		return result
	if (
		not _tool_save.validates_receipt(result.receipt)
		or result.receipt.operation_id != _tool_request.operation_id
		or result.receipt.request_hash != AtomicRequest.hash_value(_tool_request)
	):
		persistence_failed.emit(ERR_INVALID_DATA)
		return {"error": ERR_INVALID_DATA, "state": "pending"}
	var before: Array[Vector2i] = _board.revealed_cells()
	var after: BoardState = BoardState.from_dict(_board.get_level(), _tool_request.tool.after, true)
	var cells: Array[Vector2i] = []
	for cell: Vector2i in after.revealed_cells():
		if cell not in before:
			cells.append(cell)
	_board = after
	_tool_request.clear()
	_paid_feedback = true
	_progress.unbind_board()
	if not after.is_complete():
		_progress.bind_board(after)
	state_changed.emit()
	paid_tool_committed.emit(kind, cells)
	_publish(null, kind == &"hint")
	return result
