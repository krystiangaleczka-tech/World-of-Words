class_name BoardState
extends RefCounted
## @api Pure per-level state. Matching behavior follows in T-0101.

signal completed

var _level: LevelData
var _revealed: Array[Vector2i] = []
var _found: PackedStringArray = PackedStringArray()
var _bonus: PackedStringArray = PackedStringArray()
var _completion_emitted: bool = false


func _init(level: LevelData) -> void:
	_level = level


## @api Immutable content associated with this board.
func get_level() -> LevelData:
	return _level


## @api Independent snapshots; mutating these cannot change gameplay.
func revealed_cells() -> Array[Vector2i]:
	return _revealed.duplicate()


func found_words() -> PackedStringArray:
	return _found.duplicate()


func bonus_words() -> PackedStringArray:
	return _bonus.duplicate()


## @api Safe contract baseline; membership and reveal transitions arrive in T-0101.
func evaluate(tiles: PackedInt32Array) -> AttemptResult:
	if tiles.size() < LevelData.MIN_TILES:
		return null
	return AttemptResult.new(AttemptResult.Kind.INVALID, _level.spell(tiles))


## @api Reveal one occupied cell; domain transitions arrive in T-0101.
func reveal_cell(_cell: Vector2i) -> bool:
	return false


## @api All level words are found; false for unconfigured/empty content.
func is_complete() -> bool:
	return _level != null and _level.word_count() > 0 and _found.size() == _level.word_count()


## @api JSON-safe, independent snapshot keyed to the immutable level ID.
func to_dict() -> Dictionary:
	var cells: Array = []
	for cell: Vector2i in _revealed:
		cells.append([cell.x, cell.y])
	return {
		"level_id": _level.get_id(),
		"found_words": Array(_found),
		"bonus_words": Array(_bonus),
		"revealed_cells": cells,
	}


## @api Restore only consistent snapshots for this level; malformed data returns null.
static func from_dict(level: LevelData, data: Dictionary) -> BoardState:
	if level == null or data.get("level_id") != level.get_id():
		return null
	for key: String in ["found_words", "bonus_words", "revealed_cells"]:
		if not data.get(key) is Array:
			return null
	var board: BoardState = BoardState.new(level)
	for entry: Variant in data["revealed_cells"]:
		if not entry is Array or entry.size() != 2:
			return null
		for coordinate: Variant in entry:
			if not (coordinate is int or coordinate is float):
				return null
			if not is_finite(float(coordinate)) or float(coordinate) != floorf(float(coordinate)):
				return null
			if coordinate < 0 or coordinate >= LevelData.MAX_GRID:
				return null
		var cell: Vector2i = Vector2i(int(entry[0]), int(entry[1]))
		if not board._occupied(cell) or cell in board._revealed:
			return null
		board._revealed.append(cell)
	board._sync_found()
	if data["found_words"] != Array(board._found):
		return null
	for word: Variant in data["bonus_words"]:
		if not word is String or not level.bonus_words().has(word) or board._bonus.has(word):
			return null
		if board._is_level_word(word):
			return null
		board._bonus.append(word)
	board._completion_emitted = board.is_complete()
	return board


func _occupied(cell: Vector2i) -> bool:
	for index: int in _level.word_count():
		if cell in _level.word_cells(index):
			return true
	return false


func _is_level_word(word: String) -> bool:
	for index: int in _level.word_count():
		if _level.word(index) == word:
			return true
	return false


func _sync_found() -> void:
	_found.clear()
	for index: int in _level.word_count():
		var all_revealed: bool = true
		for cell: Vector2i in _level.word_cells(index):
			if cell not in _revealed:
				all_revealed = false
				break
		if all_revealed:
			_found.append(_level.word(index))
