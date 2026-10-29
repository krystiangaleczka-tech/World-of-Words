class_name BoardView
extends Control
## @api Passive, coordinate-based crossword presentation; never mutates the board.

signal wave_finished

var _ghosts: Array[Label] = []
var _flight: Tween
var _wave: Tween
var _flight_cells: Array[Vector2i] = []
var _flash_cells: Array[Vector2i] = []
var _flight_nominal: float = 0
var _motion_speed: float = 1.0
var _wave_pending: bool = false
var _board: BoardState
var _cells: Dictionary[Vector2i, GridCell] = {}
var _fits: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## @api Replace all level geometry, including intersections only once. Null clears the view.
func set_board(board: BoardState) -> void:
	_cancel_board_motion()
	for node: GridCell in _cells.values():
		remove_child(node)
		node.queue_free()
	_cells.clear()
	_board = board
	if board != null and board.get_level() != null:
		var level: LevelData = board.get_level()
		for word_index: int in level.word_count():
			var coordinates: Array[Vector2i] = level.word_cells(word_index)
			for index: int in coordinates.size():
				var cell: Vector2i = coordinates[index]
				if _cells.has(cell):
					continue
				var node: GridCell = GridCell.new()
				node.letter = level.word(word_index)[index]
				_cells[cell] = node
				add_child(node)
	_layout_cells()
	refresh()


## @api Render a fresh snapshot. Revealed cells outside a found word are hint markers.
func refresh() -> void:
	_cancel_board_motion()
	if _board == null or _cells.is_empty():
		return
	var revealed: Array[Vector2i] = _board.revealed_cells()
	var found: PackedStringArray = _board.found_words()
	var level: LevelData = _board.get_level()
	for cell: Vector2i in _cells:
		_cells[cell].state = GridCell.State.HINTED if cell in revealed else GridCell.State.EMPTY
	for index: int in level.word_count():
		if level.word(index) in found:
			for cell: Vector2i in level.word_cells(index):
				_cells[cell].state = GridCell.State.FILLED


## @api Read a unique occupied cell; empty coordinates return null.
func cell_node(cell: Vector2i) -> GridCell:
	return _cells.get(cell)


## @api Canvas-global cell centre for letter landing effects; unknown cells return Vector2.ZERO.
func cell_global_position(cell: Vector2i) -> Vector2:
	var node: GridCell = cell_node(cell)
	return node.get_global_transform() * (node.size / 2.0) if node != null else Vector2.ZERO


## @api Present a word reveal, clearing hint markers on completed words.
func reveal_word(cells: Array[Vector2i]) -> void:
	_cancel_board_motion()
	var requested: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _cells.has(cell) and cell not in requested:
			requested.append(cell)
	var reveals: Array[Vector2i] = []
	var flashes: Array[Vector2i] = []
	if _board != null:
		var level: LevelData = _board.get_level()
		for index: int in level.word_count():
			if level.word(index) not in _board.found_words():
				continue
			var word_cells: Array[Vector2i] = level.word_cells(index)
			var affected: bool = false
			for cell: Vector2i in word_cells:
				if cell in requested or _cells[cell].state != GridCell.State.FILLED:
					affected = true
			if not affected:
				continue
			for cell: Vector2i in word_cells:
				if cell not in flashes:
					flashes.append(cell)
				if (
					(cell in requested or _cells[cell].state != GridCell.State.FILLED)
					and cell not in reveals
				):
					reveals.append(cell)
	for cell: Vector2i in requested:
		if cell not in reveals:
			reveals.append(cell)
		if cell not in flashes:
			flashes.append(cell)
	_flight_cells = reveals.duplicate()
	_flash_cells = flashes
	for index: int in reveals.size():
		_cells[reveals[index]].reveal(false, index * Tokens.dur(Tokens.Motion.STAGGER) * 2)
	if reveals.is_empty() or Tokens.reduced_motion or not is_inside_tree():
		return
	var reveal_time: float = (
		(reveals.size() - 1) * Tokens.dur(Tokens.Motion.STAGGER) * 2
		+ Tokens.dur(Tokens.Motion.BASE)
	)
	_flight_nominal = reveal_time + Tokens.dur(Tokens.Motion.BASE)
	_flight = create_tween()
	_flight.tween_interval(reveal_time)
	_flight.tween_callback(_flash_word)
	_flight.tween_interval(Tokens.dur(Tokens.Motion.BASE))
	_flight.tween_callback(_finish_flight)
	set_process(true)


## @api Present one reveal without changing gameplay state.
func reveal_cell(cell: Vector2i, hinted: bool) -> void:
	var node: GridCell = cell_node(cell)
	if node != null:
		node.reveal(hinted)


## @api Already-found feedback; unknown and unrevealed coordinates are ignored.
func highlight_word(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		var node: GridCell = cell_node(cell)
		if node != null:
			node.highlight()


## @api Completion wave ordered by grid diagonal, without blocking input.
func play_wave() -> void:
	if _flight != null:
		_wave_pending = true
		var remaining: float = maxf(0, _flight_nominal - _flight.get_total_elapsed_time())
		_motion_speed = maxf(
			1,
			(
				(remaining + _nominal_wave_duration())
				/ (
					Tokens.dur(Tokens.Motion.CELEBRATE)
					- Tokens.dur(Tokens.Motion.SLOW)
					- Tokens.dur(Tokens.Motion.STAGGER)
				)
			)
		)
		_flight.set_speed_scale(_motion_speed)
		for coordinate: Vector2i in _cells:
			_cells[coordinate].set_motion_speed(_motion_speed)
		return
	if _wave != null:
		_wave.kill()
		_wave = null
	for cell: Vector2i in _cells:
		_cells[cell].wave(_wave_delay(cell))
	if Tokens.reduced_motion or not is_inside_tree():
		wave_finished.emit()
		return
	_wave = create_tween().set_speed_scale(_motion_speed)
	_wave.tween_interval(_nominal_wave_duration())
	_wave.tween_callback(_finish_wave)
	set_process(true)


## @api Bound wave + completion-layer SLOW to CELEBRATE.
func wave_duration() -> float:
	return _nominal_wave_duration() / _motion_speed


func _nominal_wave_duration() -> float:
	var last: float = 0
	for cell: Vector2i in _cells:
		if _cells[cell].state != GridCell.State.EMPTY:
			last = maxf(last, _wave_delay(cell))
	return 0 if Tokens.reduced_motion else last + Tokens.dur(Tokens.Motion.FAST) * 2


func _wave_delay(cell: Vector2i) -> float:
	return minf(
		(cell.x + cell.y) * Tokens.dur(Tokens.Motion.STAGGER),
		(
			Tokens.dur(Tokens.Motion.CELEBRATE)
			- Tokens.dur(Tokens.Motion.SLOW)
			- Tokens.dur(Tokens.Motion.FAST) * 2
			- Tokens.dur(Tokens.Motion.STAGGER)
		)
	)


func _finish_wave() -> void:
	if _wave != null:
		_wave.kill()
	_wave = null
	_motion_speed = 1
	for coordinate: Vector2i in _cells:
		_cells[coordinate].set_motion_speed(1)
	set_process(false)
	wave_finished.emit()


## @api False when the available rect requires cells below the content minimum.
func fits_minimum() -> bool:
	return _fits


## @api Grid columns and rows of the loaded board; zero before a board is set.
func grid_dimensions() -> Vector2i:
	if _board == null:
		return Vector2i.ZERO
	return _board.get_level().grid_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cells()


func _layout_cells() -> void:
	_cancel_board_motion(true)
	_fits = true
	if _cells.is_empty():
		return
	var dimensions: Vector2 = Vector2(_board.get_level().grid_size())
	var gaps: Vector2 = dimensions - Vector2.ONE
	var minimum: Vector2 = dimensions * Tokens.Layout.CELL_MIN + gaps * Tokens.Space.XS
	var available: Vector2 = size.max(Vector2.ZERO)
	var shrink: float = minf(1.0, minf(available.x / minimum.x, available.y / minimum.y))
	var gap: float = Tokens.Space.XS * shrink
	var room: Vector2 = (available - gaps * gap) / dimensions
	var side: float = maxf(0.0, minf(Tokens.Layout.CELL_MAX, minf(room.x, room.y)))
	_fits = side >= Tokens.Layout.CELL_MIN
	var origin: Vector2 = (available - dimensions * side - gaps * gap) / 2.0
	for cell: Vector2i in _cells:
		_cells[cell].position = origin + Vector2(cell) * (side + gap)
		_cells[cell].size = Vector2.ONE * side


## @api Shared final layout. Empty for invalid inputs; tiny valid rectangles remain bounded.
## grid_size (cols, rows) lets the grid keep only the height its capped cells need, below the
## GRID_MIN_RATIO share; zero keeps the share as a floor.
static func play_area_rects(
	available: Vector2,
	layout: StringName,
	preview_height: float,
	actions_height: float = 0,
	grid_size: Vector2i = Vector2i.ZERO
) -> Dictionary[StringName, Rect2]:
	var result: Dictionary[StringName, Rect2] = {}
	if (
		layout not in [&"COMPACT", &"REGULAR", &"TABLET"]
		or not available.is_finite()
		or available.x <= 0
		or available.y <= 0
		or not is_finite(preview_height)
		or preview_height < 0
		or not is_finite(actions_height)
		or actions_height < 0
	):
		return result
	var width: float = minf(available.x, Tokens.Layout.MAX_CONTENT_WIDTH)
	var left: float = (available.x - width) / 2
	var gap: float = Tokens.Space.XS if layout == &"COMPACT" else Tokens.Space.S
	var overhead: float = preview_height + actions_height + gap * 3 + Tokens.Space.L * 2
	# Scale structural overhead only for impossible tiny hosts; normal classes use exact tokens.
	var compression: float = minf(1, available.y / maxf(overhead, 1))
	preview_height *= compression
	actions_height *= compression
	gap *= compression
	var padding: float = Tokens.Space.L * compression
	var ratio: float = (
		Tokens.Layout.WHEEL_COMPACT_RATIO
		if layout == &"COMPACT"
		else Tokens.Layout.WHEEL_WIDTH_RATIO
	)
	var diameter: float = minf(
		width, clampf(width * ratio, Tokens.Layout.WHEEL_MIN, Tokens.Layout.WHEEL_MAX)
	)
	var grid_floor: float = available.y * Tokens.Layout.GRID_MIN_RATIO
	if grid_size.x > 0 and grid_size.y > 0:
		grid_floor = minf(grid_floor, _natural_grid_height(grid_size, width))
	diameter = maxf(
		0,
		minf(
			diameter,
			available.y - grid_floor - preview_height - actions_height - gap * 3 - padding * 2
		)
	)
	var board_height: float = maxf(
		0, available.y - diameter - preview_height - actions_height - gap * 3 - padding * 2
	)
	result[&"board"] = Rect2(Vector2(left, 0), Vector2(width, board_height))
	result[&"preview"] = Rect2(Vector2(left, board_height + gap), Vector2(width, preview_height))
	result[&"actions"] = Rect2(
		Vector2(left, board_height + preview_height + gap * 2), Vector2(width, actions_height)
	)
	result[&"wheel"] = Rect2(
		Vector2((available.x - diameter) / 2, available.y - padding - diameter),
		Vector2.ONE * diameter
	)
	return result


static func _natural_grid_height(grid: Vector2i, width: float) -> float:
	var room: float = (width - (grid.x - 1) * Tokens.Space.XS) / grid.x
	var side: float = minf(Tokens.Layout.CELL_MAX, room)
	return maxf(0, side * grid.y + (grid.y - 1) * Tokens.Space.XS)


func _enter_tree() -> void:
	for index: int in LevelData.MAX_TILES:
		var ghost: Label = Label.new()
		ghost.name = "FlightLetter%d" % index
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ghosts.append(ghost)
	set_process(false)


## @api Canvas-global origin, ordered new cells, optional complete word for intersection flash.
func fly_word(cells: Array[Vector2i], origin: Vector2, whole_word: Array[Vector2i] = []) -> Error:
	if (
		not origin.is_finite()
		or cells.size() > LevelData.MAX_TILES
		or whole_word.size() > LevelData.MAX_TILES
	):
		return ERR_INVALID_PARAMETER
	for cell: Vector2i in cells:
		if not _cells.has(cell) or cells.count(cell) > 1:
			return ERR_INVALID_PARAMETER
	for cell: Vector2i in whole_word:
		if not _cells.has(cell) or whole_word.count(cell) > 1:
			return ERR_INVALID_PARAMETER
	if not is_inside_tree() or not is_node_ready() or _ghosts.is_empty():
		return ERR_UNCONFIGURED
	_cancel_board_motion()
	_flight_cells = cells.duplicate()
	_flash_cells = whole_word.duplicate() if not whole_word.is_empty() else cells.duplicate()
	for cell: Vector2i in _flash_cells:
		_cells[cell].state = GridCell.State.FILLED
	if Tokens.reduced_motion:
		for cell: Vector2i in cells:
			_cells[cell].fade_filled()
		return OK
	_flight_nominal = (
		maxf(0, (cells.size() - 1) * Tokens.dur(Tokens.Motion.STAGGER))
		+ Tokens.dur(Tokens.Motion.BASE) * 2
		+ Tokens.dur(Tokens.Motion.FAST)
	)
	var local_origin: Vector2 = get_global_transform().affine_inverse() * origin
	var font_size: int = get_theme_font_size(&"font_size", &"Preview")
	_flight = create_tween().set_parallel(true)
	for index: int in cells.size():
		var cell: Vector2i = cells[index]
		var node: GridCell = _cells[cell]
		node.prepare_landing()
		var ghost: Label = _ghosts[index]
		ghost.text = node.letter
		ghost.theme_type_variation = &"Preview"
		ghost.add_theme_color_override("font_color", get_theme_color(&"TEXT", &"Palette"))
		ghost.size = Vector2.ONE * (font_size + Tokens.Space.M)
		ghost.pivot_offset = ghost.size / 2
		ghost.position = (
			local_origin
			- ghost.size / 2
			+ Vector2(
				(index - (cells.size() - 1) / 2.0) * font_size * Tokens.Type.CELL_LETTER_RATIO, 0
			)
		)
		ghost.scale = Vector2.ONE
		add_child(ghost)
		var delay: float = index * Tokens.dur(Tokens.Motion.STAGGER)
		(
			_flight
			. tween_property(
				ghost,
				"position",
				node.position + node.size / 2 - ghost.size / 2,
				Tokens.dur(Tokens.Motion.BASE)
			)
			. set_delay(delay)
			. set_trans(Tokens.Ease.IN_OUT.x)
			. set_ease(Tokens.Ease.IN_OUT.y)
		)
		(
			_flight
			. tween_property(
				ghost,
				"scale",
				Vector2.ONE * node.size.y * Tokens.Type.CELL_LETTER_RATIO / font_size,
				Tokens.dur(Tokens.Motion.BASE)
			)
			. set_delay(delay)
			. set_trans(Tokens.Ease.IN_OUT.x)
			. set_ease(Tokens.Ease.IN_OUT.y)
		)
		_flight.tween_callback(_land_letter.bind(index, cell)).set_delay(
			delay + Tokens.dur(Tokens.Motion.BASE)
		)
	_flight.chain().tween_interval(Tokens.dur(Tokens.Motion.FAST))
	_flight.chain().tween_callback(_flash_word)
	_flight.chain().tween_interval(Tokens.dur(Tokens.Motion.BASE))
	_flight.chain().tween_callback(_finish_flight)
	set_process(true)
	return OK


## @api Presentation state independent of gameplay completion.
func flight_state() -> StringName:
	return &"flying" if _flight != null else &"idle"


func _land_letter(index: int, cell: Vector2i) -> void:
	if _ghosts[index].get_parent() == self:
		remove_child(_ghosts[index])
	_cells[cell].land()


func _flash_word() -> void:
	for cell: Vector2i in _flash_cells:
		_cells[cell].flash()


func _finish_flight() -> void:
	if _flight != null:
		_flight.kill()
	_flight = null
	var pending: bool = _wave_pending
	_wave_pending = false
	set_process(false)
	if pending:
		play_wave()


func _cancel_board_motion(complete_wave: bool = false) -> void:
	var pending: bool = _wave != null or _wave_pending
	if _flight != null:
		_flight.kill()
		_flight = null
	if _wave != null:
		_wave.kill()
		_wave = null
	for ghost: Label in _ghosts:
		if ghost.get_parent() == self:
			remove_child(ghost)
	for coordinate: Vector2i in _cells:
		_cells[coordinate].finish_motion()
		_cells[coordinate].set_motion_speed(1)
	_motion_speed = 1
	_flight_cells.clear()
	_flash_cells.clear()
	_wave_pending = false
	set_process(false)
	if complete_wave and pending and is_inside_tree():
		wave_finished.emit()


func _process(_delta: float) -> void:
	if Tokens.reduced_motion:
		var pending: bool = _wave != null or _wave_pending
		_cancel_board_motion()
		for coordinate: Vector2i in _cells:
			_cells[coordinate].finish_motion()
		if pending:
			wave_finished.emit()


func _exit_tree() -> void:
	_cancel_board_motion()
	for ghost: Label in _ghosts:
		ghost.free()
	_ghosts.clear()
