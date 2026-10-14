class_name LocationPostcard
extends PanelContainer
## @api Passive caller image/progress; partitions do not award or spend stars.

const COMPLETE_KEY: String = "ui.postcard.complete"
const PROGRESS_KEY: String = "ui.postcard.progress"
const MAX_PIECES: int = 16  # Rendering capacity covers documented configurable range.
var texture: Texture2D:
	get:
		return _texture
var pieces_total: int:
	get:
		return _total
var pieces_revealed: int:
	get:
		return _revealed
var preset: StringName:
	get:
		return _preset
var state: StringName:
	get:
		if _reveal != null and _reveal.is_running():
			return &"revealing"
		if _total > 0 and _revealed == _total:
			return &"complete"
		return &"locked" if _revealed == 0 else &"in_progress"
var _texture: Texture2D
var _total: int = 0
var _revealed: int = 0
var _preset: StringName = &"full"
var _regions: Array[Rect2] = []
var _alphas: PackedFloat32Array = PackedFloat32Array()
var _art: PieceArt
var _caption: Label
var _stamp: TextureRect
var _lock: TextureRect
var _reveal: Tween
var _refreshing: bool = false
var _layout_guard: bool = false
var _catalog: LocaleCatalog = LocaleCatalog.new()


class PieceArt:
	extends Control
	var card: LocationPostcard
	var paper: StyleBoxFlat = StyleBoxFlat.new()

	func _draw() -> void:
		if card == null or card.texture == null:
			return
		paper.bg_color = get_theme_color(&"SURFACE_ALT", &"Palette")
		paper.border_color = get_theme_color(&"STROKE", &"Palette")
		paper.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
		for index: int in card.pieces_total:
			var normalized: Rect2 = card.piece_region(index)
			var rect: Rect2 = Rect2(normalized.position * size, normalized.size * size)
			draw_style_box(paper, rect)
			for offset: int in range(Tokens.Space.S, int(rect.size.x), Tokens.Space.S * 2):
				var start: Vector2 = rect.position + Vector2(offset, Tokens.Space.XS)
				var end: Vector2 = (
					start + Vector2(minf(Tokens.Space.XS, rect.end.x - start.x), Tokens.Space.XS)
				)
				if end.y < rect.end.y:
					draw_line(start, end, paper.border_color, Tokens.Action.OUTLINE_WIDTH)
			if card._alphas[index] > 0:
				var source: Rect2 = Rect2(
					normalized.position * card.texture.get_size(),
					normalized.size * card.texture.get_size()
				)
				var ink: Color = get_theme_color(&"ON_PRIMARY", &"Palette")
				ink.a = card._alphas[index]
				draw_texture_rect_region(card.texture, rect, source, ink)


## @api Invalid configuration preserves image, counts, geometry and active reveal atomically.
func configure(image: Texture2D, total: int, revealed: int, mode: StringName = &"full") -> Error:
	if (
		image == null
		or image.get_width() <= 0
		or image.get_height() <= 0
		or total < 1
		or total > MAX_PIECES
		or revealed < 0
		or revealed > total
		or mode not in [&"thumb", &"full"]
	):
		return ERR_INVALID_PARAMETER
	_settle_reveal()
	_texture = image
	_total = total
	_revealed = revealed
	_preset = mode
	_regions.clear()
	_alphas.resize(total)
	var columns: int = ceili(sqrt(float(total)))
	var rows: int = ceili(float(total) / columns)
	for index: int in total:
		var row: int = index / columns
		var in_row: int = mini(columns, total - row * columns)
		_regions.append(
			Rect2(float(index % columns) / in_row, float(row) / rows, 1.0 / in_row, 1.0 / rows)
		)
		_alphas[index] = 1.0 if index < revealed else 0.0
	_refresh_copy()
	_refresh_theme()
	_layout_art()
	return OK


## @api Normalized crop, with empty rectangle for missing indices.
func piece_region(index: int) -> Rect2:
	return _regions[index] if index >= 0 and index < _regions.size() else Rect2()


## @api Logical count changes immediately; only newest piece animates, no progress mutation.
func reveal_next() -> Error:
	if _texture == null or _total == 0 or not is_inside_tree() or not is_node_ready():
		return ERR_UNCONFIGURED
	if _revealed >= _total:
		return ERR_ALREADY_IN_USE
	_settle_reveal()
	var index: int = _revealed
	_revealed += 1
	if Tokens.reduced_motion:
		_alphas[index] = 1
		_refresh_copy()
		return OK
	_reveal = create_tween().set_trans(Tokens.Ease.OUT.x).set_ease(Tokens.Ease.OUT.y)
	_reveal.tween_method(_show_piece.bind(index), 0.0, 1.0, Tokens.dur(Tokens.Motion.BASE))
	_reveal.tween_callback(_finish_reveal)
	_refresh_copy()
	set_process(true)
	return OK


func _show_piece(alpha: float, index: int) -> void:
	_alphas[index] = alpha
	_art.queue_redraw()


func _finish_reveal() -> void:
	_reveal = null
	_refresh_copy()
	set_process(false)


func _settle_reveal() -> void:
	if _reveal != null:
		_reveal.kill()
		_reveal = null
	for index: int in _revealed:
		_alphas[index] = 1
	set_process(false)


func _enter_tree() -> void:
	_catalog.register_all()
	if _art != null:
		_connect_layout()
		_refresh_copy()
		_refresh_theme()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.Space.S)
	add_child(column)
	_art = PieceArt.new()
	_art.card = self
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_art)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.Space.S)
	column.add_child(row)
	_stamp = CatalogSurface.icon(preload("res://assets/icons/check.svg"))
	row.add_child(_stamp)
	_lock = CatalogSurface.icon(preload("res://assets/icons/lock.svg"))
	row.add_child(_lock)
	_caption = CatalogSurface.label(&"Caption")
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_caption)
	_connect_layout()
	_refresh_copy()
	_refresh_theme()
	_layout_art()
	set_process(false)


func _refresh_copy() -> void:
	var complete: bool = state == &"complete"
	accessibility_name = COMPLETE_KEY if complete else PROGRESS_KEY
	accessibility_description = str(_revealed) + " / " + str(_total)
	if _caption != null:
		_caption.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER if _preset == &"full" else HORIZONTAL_ALIGNMENT_LEFT
		)
		_caption.text = tr(COMPLETE_KEY) if complete else str(_revealed) + " / " + str(_total)
		_stamp.visible = complete
		_lock.visible = state == &"locked"
		_art.queue_redraw()


func _layout_art() -> void:
	if _art == null or _layout_guard:
		return
	_layout_guard = true
	var width: float = (
		Tokens.Touch.MIN_TARGET * 2.0 if _preset == &"thumb" else Tokens.Touch.MIN_TARGET
	)
	var padding: int = Tokens.Space.S if _preset == &"full" else Tokens.Space.M
	var padded_width: float = width + padding * 2
	custom_minimum_size.x = padded_width
	size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if _preset == &"thumb" else Control.SIZE_EXPAND_FILL
	)
	var actual: float = maxf(width, size.x - padding * 2)
	var aspect: float = (
		_texture.get_width() / float(_texture.get_height()) if _texture != null else 1.0
	)
	_art.custom_minimum_size.y = actual / aspect
	_layout_guard = false


func _refresh_theme() -> void:
	if _art == null or _refreshing:
		return
	_refreshing = true
	add_theme_stylebox_override(
		"panel",
		CatalogSurface.panel(
			self,
			Tokens.Space.S if _preset == &"full" else Tokens.Space.M,
			Tokens.Radius.M,
			&"LOW" if _preset == &"full" else &"MID"
		)
	)
	_stamp.modulate = get_theme_color(&"SUCCESS", &"Palette")
	_lock.modulate = get_theme_color(&"TEXT", &"Palette")
	_art.queue_redraw()
	_refreshing = false


func _connect_layout() -> void:
	if not resized.is_connected(_layout_art):
		resized.connect(_layout_art)


func _process(_delta: float) -> void:
	if Tokens.reduced_motion:
		_settle_reveal()
		# Only passive text/visibility changes; no nodes or styles allocated here.
		_refresh_copy()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	_settle_reveal()
	_refresh_copy()
	if resized.is_connected(_layout_art):
		resized.disconnect(_layout_art)
	_catalog.unregister()
