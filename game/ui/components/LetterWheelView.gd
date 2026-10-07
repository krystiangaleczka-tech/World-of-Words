class_name LetterWheelView
extends Control
## @api Stable tile identities with geometry independent of pointer state.

signal chain_changed(indices: PackedInt32Array)
signal word_attempted(indices: PackedInt32Array)
signal tile_added(index: int)

const MOUSE_ID: int = -2

var _letters: PackedStringArray = PackedStringArray()
var _centers: PackedVector2Array = PackedVector2Array()
var _tiles: Array[LetterTile] = []
var _order: PackedInt32Array = PackedInt32Array()
var _locked: bool = false
var _shuffling: bool = false
var _shuffle_tween: Tween
var _shuffle_generation: int = 0
var _tile_radius: float = 0.0
var _owner: int = -1
var _chain: PackedInt32Array = PackedInt32Array()
var _line: PackedVector2Array = PackedVector2Array()
var _length: int = 0
var _pointer: Vector2 = Vector2.ZERO
var _last_hit_position: Vector2 = Vector2.ZERO


func _init() -> void:
	_chain.resize(LevelData.MAX_TILES)
	_line.resize(LevelData.MAX_TILES + 1)


func _ready() -> void:
	resized.connect(_layout_tiles)
	_layout_tiles()


## @api Replace content. Only the supported 3–8 tile range is accepted.
func set_letters(letters: PackedStringArray) -> void:
	_cancel_shuffle()
	pointer_end(_owner, true)
	for tile: LetterTile in _tiles:
		remove_child(tile)
		tile.queue_free()
	_tiles.clear()
	_letters = (
		letters.duplicate() if letters.size() >= 3 and letters.size() <= 8 else PackedStringArray()
	)
	_order.resize(_letters.size())
	for index: int in _letters.size():
		_order[index] = index
		var tile: LetterTile = LetterTile.new()
		tile.index = index
		tile.letter = _letters[index]
		_tiles.append(tile)
		add_child(tile)
	_layout_tiles()


## @api Lock input and cancel any current gesture without submitting.
func set_locked(locked: bool) -> void:
	_locked = locked
	if locked:
		pointer_end(_owner, true)


func is_locked() -> bool:
	return _locked or _shuffling


func is_dragging() -> bool:
	return _owner != -1


func current_chain() -> PackedInt32Array:
	return _chain.slice(0, _length)


func tile_position(index: int) -> Vector2:
	return _centers[index] if index >= 0 and index < _centers.size() else Vector2.ZERO


## @api Shuffle visible slots while retaining each tile's original identity.
func shuffle(rng: RandomNumberGenerator) -> bool:
	if is_locked() or is_dragging() or rng == null:
		return false
	var next_order: PackedInt32Array = Shuffle.permute(_order, _letters, rng)
	if next_order.is_empty():
		return false
	var visible_change: bool = false
	for slot: int in _order.size():
		if _letters[next_order[slot]] != _letters[_order[slot]]:
			visible_change = true
			break
	if not visible_change:
		return false
	_order = next_order
	if Tokens.reduced_motion or not is_inside_tree():
		_layout_tiles()
		return true
	_shuffling = true
	_shuffle_generation += 1
	var generation: int = _shuffle_generation
	var diameter: float = minf(size.x, size.y)
	var slots: PackedVector2Array = WheelGeometry.positions(
		_order.size(), diameter * Tokens.Layout.WHEEL_RING_RATIO, size / 2.0
	)
	var center: Vector2 = size / 2.0
	var radius: float = diameter * Tokens.Layout.WHEEL_RING_RATIO
	_shuffle_tween = create_tween().set_parallel(true)
	_shuffle_tween.set_trans(Tokens.Ease.IN_OUT.x).set_ease(Tokens.Ease.IN_OUT.y)
	for slot: int in _order.size():
		var tile_id: int = _order[slot]
		var start: Vector2 = _tiles[tile_id].position + _tiles[tile_id].size / 2.0
		var start_angle: float = (start - center).angle()
		var angle_delta: float = wrapf((slots[slot] - center).angle() - start_angle, -PI, PI)
		_centers[tile_id] = slots[slot]
		_shuffle_tween.tween_method(
			_move_tile_on_arc.bind(tile_id, start_angle, angle_delta, radius, center),
			0.0,
			1.0,
			Tokens.dur(Tokens.Motion.BASE)
		)
	_shuffle_tween.chain().tween_callback(_finish_shuffle.bind(generation))
	return true


## @api Slot-to-tile mapping; callers may mutate the returned copy.
func tile_order() -> PackedInt32Array:
	return _order.duplicate()


func _move_tile_on_arc(
	progress: float,
	tile_id: int,
	start_angle: float,
	angle_delta: float,
	radius: float,
	center: Vector2
) -> void:
	_tiles[tile_id].position = (
		center
		+ Vector2.from_angle(start_angle + angle_delta * progress) * radius
		- _tiles[tile_id].size / 2.0
	)


func _finish_shuffle(generation: int) -> void:
	if generation != _shuffle_generation or not _shuffling:
		return
	_shuffle_tween = null
	for tile_id: int in _tiles.size():
		_tiles[tile_id].position = _centers[tile_id] - _tiles[tile_id].size / 2.0
	_shuffling = false


func _cancel_shuffle() -> void:
	_shuffle_generation += 1
	if _shuffle_tween != null:
		_shuffle_tween.kill()
		_shuffle_tween = null
	_shuffling = false


func _layout_tiles() -> void:
	_cancel_shuffle()
	pointer_end(_owner, true)
	var diameter: float = minf(size.x, size.y)
	_tile_radius = diameter * Tokens.Layout.TILE_RADIUS_RATIO
	var slots: PackedVector2Array = WheelGeometry.positions(
		_letters.size(), diameter * Tokens.Layout.WHEEL_RING_RATIO, size / 2.0
	)
	_centers.resize(_letters.size())
	for slot: int in _order.size():
		var tile_id: int = _order[slot]
		_centers[tile_id] = slots[slot]
		_tiles[tile_id].size = Vector2.ONE * _tile_radius * 2.0
		_tiles[tile_id].position = slots[slot] - _tiles[tile_id].size / 2.0
	queue_redraw()


func _draw() -> void:
	draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, Tokens.Palette.SURFACE_ALT)
	for segment: int in maxi(line_point_count() - 1, 0):
		draw_line(
			_line[segment], _line[segment + 1], Tokens.Palette.LINE, Tokens.Layout.LINE_WIDTH, true
		)


## @api Start only on a tile; all subsequent events belong to this pointer.
func pointer_begin(id: int, point: Vector2) -> void:
	if id == -1 or is_locked() or is_dragging():
		return
	var hit: int = WheelGeometry.hit_test(
		point, _centers, _tile_radius * Tokens.Touch.TILE_HIT_RATIO
	)
	if hit < 0:
		return
	_owner = id
	_last_hit_position = point
	_pointer = point
	_visit(hit)


## @api Motion uses fixed buffers. A copied chain is emitted only when it changes.
func pointer_move(id: int, point: Vector2) -> void:
	if id != _owner or not is_dragging():
		return
	_pointer = point
	_update_line()
	if (
		point.distance_squared_to(_last_hit_position)
		< Tokens.Touch.DRAG_SLOP * Tokens.Touch.DRAG_SLOP
	):
		return
	var hit: int = WheelGeometry.hit_test(
		point, _centers, _tile_radius * Tokens.Touch.TILE_HIT_RATIO
	)
	if hit >= 0:
		_visit(hit)
		_last_hit_position = point


## @api Clear before emitting an attempt; cancellation never submits.
func pointer_end(id: int, canceled: bool = false) -> void:
	if not is_dragging() or id != _owner:
		return
	var attempt: PackedInt32Array = (
		current_chain() if not canceled and _length >= 3 else PackedInt32Array()
	)
	_owner = -1
	_length = 0
	for tile: LetterTile in _tiles:
		tile.selected = false
	_update_line()
	chain_changed.emit(current_chain())
	if not attempt.is_empty():
		word_attempted.emit(attempt)


func _visit(hit: int) -> void:
	if _length >= 2 and _chain[_length - 2] == hit:
		_length -= 1
		_tiles[_chain[_length]].selected = false
		_update_line()
		chain_changed.emit(current_chain())
		return
	for index: int in _length:
		if _chain[index] == hit:
			return
	_chain[_length] = hit
	_length += 1
	_tiles[hit].selected = true
	_update_line()
	chain_changed.emit(current_chain())
	tile_added.emit(hit)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			pointer_begin(touch.index, touch.position)
		else:
			pointer_end(touch.index, touch.canceled)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		pointer_move(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				pointer_begin(MOUSE_ID, mouse.position)
			else:
				pointer_end(MOUSE_ID)
	elif event is InputEventMouseMotion:
		pointer_move(MOUSE_ID, (event as InputEventMouseMotion).position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pointer_end(_owner, true)


func _exit_tree() -> void:
	_cancel_shuffle()
	pointer_end(_owner, true)
	if resized.is_connected(_layout_tiles):
		resized.disconnect(_layout_tiles)


## @api Selected tile centers followed by the owner's pointer; no points when idle.
func line_point_count() -> int:
	return _length + 1 if is_dragging() else 0


func line_point(index: int) -> Vector2:
	return _line[index] if index >= 0 and index < line_point_count() else Vector2.ZERO


func _update_line() -> void:
	for index: int in _length:
		_line[index] = _centers[_chain[index]]
	if is_dragging():
		_line[_length] = _pointer
	queue_redraw()
