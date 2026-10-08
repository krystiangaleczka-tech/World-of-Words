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


## @api Inject one active board, its progress service and the side-effect bus.
## Reconfiguration replaces references without gameplay, persistence or signal side effects.
func configure(board: BoardState, progress: PROGRESS_SCRIPT, event_bus: Node) -> void:
	_board = board
	_progress = progress
	_event_bus = event_bus


## @api The active board, or null before configuration.
func get_board() -> BoardState:
	return _board


## @api Short attempts are ignored without mutation, result or effects.
## Matching and persistence-before-effects orchestration arrive in T-0116.
func submit(tiles: PackedInt32Array) -> AttemptResult:
	if tiles.size() < LevelData.MIN_TILES:
		return null
	return null


## @api Free hint orchestration arrives in T-0116; currently no mutation is performed.
func hint() -> bool:
	return false


## @api Read live board completion; an unconfigured controller is incomplete.
func is_complete() -> bool:
	return _board != null and _board.is_complete()
