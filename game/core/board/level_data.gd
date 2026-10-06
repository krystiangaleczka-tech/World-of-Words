class_name LevelData
extends RefCounted
## @api Immutable level as the game reads it (CONTENT.md#level-schema).
## Tiles are addressed by index.
## Only id, slot, letters, words, bonus and grid are read; the rest is pipeline metadata.

const MIN_TILES: int = 3
const MAX_TILES: int = 8
const MAX_GRID: int = 10

var _id: String = ""
var _slot: int = 0
var _letters: PackedStringArray = PackedStringArray()
var _words: PackedStringArray = PackedStringArray()
var _cells: Array[Array] = []
var _bonus: PackedStringArray = PackedStringArray()
var _grid: Vector2i = Vector2i.ZERO


## @api Build a level from parsed JSON. Returns null when a game field is missing or inconsistent.
static func from_dict(data: Dictionary) -> LevelData:
	var level: LevelData = LevelData.new()
	if not level._read(data):
		return null
	return level


## @api Stable level id, e.g. "pl-c-000001".
func get_id() -> String:
	return _id


## @api Campaign slot; 0 for daily levels.
func get_slot() -> int:
	return _slot


## @api Number of wheel tiles.
func tile_count() -> int:
	return _letters.size()


## @api Letter on one tile; "" for an index out of range.
func tile_letter(index: int) -> String:
	if index < 0 or index >= _letters.size():
		return ""
	return _letters[index]


## @api Tile letters in their initial order (a copy).
func get_letters() -> PackedStringArray:
	return _letters.duplicate()


## @api Number of level words; their order is the hint tie-break order.
func word_count() -> int:
	return _words.size()


## @api Level word by index; "" for an index out of range.
func word(index: int) -> String:
	if index < 0 or index >= _words.size():
		return ""
	return _words[index]


## @api Grid cells of one level word, first letter first (a copy).
func word_cells(index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if index >= 0 and index < _cells.size():
		cells.assign(_cells[index])
	return cells


## @api Complete bonus list (a copy).
func bonus_words() -> PackedStringArray:
	return _bonus.duplicate()


## @api Grid bounding box in cells.
func grid_size() -> Vector2i:
	return _grid


## @api Word spelled by tile indices; "" if an index is out of range or used twice.
func spell(tiles: PackedInt32Array) -> String:
	var used: PackedByteArray = PackedByteArray()
	used.resize(_letters.size())
	var result: String = ""
	for tile: int in tiles:
		if tile < 0 or tile >= _letters.size() or used[tile] != 0:
			return ""
		used[tile] = 1
		result += _letters[tile]
	return result


func _read(data: Dictionary) -> bool:
	if not data.get("id") is String or (data["id"] as String).is_empty():
		return false
	_id = data["id"]
	if data.has("slot"):
		_slot = _integer(data["slot"], 1, 1 << 30)
		if _slot < 1:
			return false
	return (
		_read_letters(data.get("letters"))
		and _read_grid(data.get("grid"))
		and (_read_words(data.get("words")) and _read_bonus(data.get("bonus")))
	)


func _read_letters(value: Variant) -> bool:
	if not value is Array:
		return false
	var letters: Array = value
	if letters.size() < MIN_TILES or letters.size() > MAX_TILES:
		return false
	for letter: Variant in letters:
		if not letter is String or (letter as String).length() != 1:
			return false
		_letters.append(letter)
	return true


func _read_grid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var grid: Dictionary = value
	_grid = Vector2i(_integer(grid.get("w"), 1, MAX_GRID), _integer(grid.get("h"), 1, MAX_GRID))
	return _grid.x > 0 and _grid.y > 0


func _read_words(value: Variant) -> bool:
	if not value is Array or (value as Array).is_empty():
		return false
	var occupied: Dictionary = {}
	for entry: Variant in value:
		if not entry is Dictionary or not _place(entry, occupied):
			return false
	return true


# Append one placement; false if malformed, outside the grid or clashing with a placed letter.
func _place(placement: Dictionary, occupied: Dictionary) -> bool:
	var text: Variant = placement.get("w")
	var direction: Variant = placement.get("dir")
	var start: Vector2i = Vector2i(
		_integer(placement.get("x"), 0, MAX_GRID - 1), _integer(placement.get("y"), 0, MAX_GRID - 1)
	)
	if not text is String or (text as String).length() < MIN_TILES or start.x < 0 or start.y < 0:
		return false
	if direction != "h" and direction != "v":
		return false
	var step: Vector2i = Vector2i.RIGHT if direction == "h" else Vector2i.DOWN
	var cells: Array[Vector2i] = []
	for offset: int in (text as String).length():
		var cell: Vector2i = start + step * offset
		var letter: String = (text as String)[offset]
		if cell.x >= _grid.x or cell.y >= _grid.y or occupied.get(cell, letter) != letter:
			return false
		occupied[cell] = letter
		cells.append(cell)
	_words.append(text)
	_cells.append(cells)
	return true


func _read_bonus(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is String:
			return false
		_bonus.append(entry)
	return true


# JSON numbers arrive as float; accept only integral values inside [low, high], else -1.
static func _integer(value: Variant, low: int, high: int) -> int:
	if not (value is float or value is int):
		return -1
	var number: float = float(value)
	if number != floorf(number) or number < low or number > high:
		return -1
	return int(number)
