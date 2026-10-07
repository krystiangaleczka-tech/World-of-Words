class_name LetterWheelView
extends Control
## @api Stable tile identities with geometry independent of pointer state.

signal chain_changed(indices: PackedInt32Array)
signal word_attempted(indices: PackedInt32Array)
signal tile_added(index: int)

var _letters: PackedStringArray = PackedStringArray()
var _centers: PackedVector2Array = PackedVector2Array()
var _tiles: Array[LetterTile] = []
var _locked: bool = false
var _tile_radius: float = 0.0


func _ready() -> void:
	resized.connect(_layout_tiles)
	_layout_tiles()


## @api Replace content. Only the supported 3–8 tile range is accepted.
func set_letters(letters: PackedStringArray) -> void:
	for tile: LetterTile in _tiles:
		remove_child(tile)
		tile.queue_free()
	_tiles.clear()
	_letters = (
		letters.duplicate() if letters.size() >= 3 and letters.size() <= 8 else PackedStringArray()
	)
	for index: int in _letters.size():
		var tile: LetterTile = LetterTile.new()
		tile.index = index
		tile.letter = _letters[index]
		_tiles.append(tile)
		add_child(tile)
	_layout_tiles()


## @api Lock future input; cancellation is implemented in T-0105.
func set_locked(locked: bool) -> void:
	_locked = locked


func is_locked() -> bool:
	return _locked


func is_dragging() -> bool:
	return false


func current_chain() -> PackedInt32Array:
	return PackedInt32Array()


func tile_position(index: int) -> Vector2:
	return _centers[index] if index >= 0 and index < _centers.size() else Vector2.ZERO


## @api T-0108 supplies deterministic permutation and animation.
func shuffle(_rng: RandomNumberGenerator) -> bool:
	return false


func _layout_tiles() -> void:
	var diameter: float = minf(size.x, size.y)
	_tile_radius = diameter * Tokens.Layout.TILE_RADIUS_RATIO
	_centers = WheelGeometry.positions(
		_letters.size(), diameter * Tokens.Layout.WHEEL_RING_RATIO, size / 2.0
	)
	for index: int in _centers.size():
		_tiles[index].size = Vector2.ONE * _tile_radius * 2.0
		_tiles[index].position = _centers[index] - _tiles[index].size / 2.0
	queue_redraw()


func _draw() -> void:
	draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, Tokens.Palette.SURFACE_ALT)
