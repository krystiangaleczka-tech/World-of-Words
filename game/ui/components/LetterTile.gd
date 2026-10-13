class_name LetterTile
extends Control
## @api Passive wheel tile; input belongs exclusively to LetterWheelView.

var letter: String = "":
	set(value):
		letter = value
		queue_redraw()
var index: int = -1
var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		_from_scale = scale.x
		_elapsed = 0.0
		if Tokens.reduced_motion or not is_inside_tree():
			_settle()
		else:
			set_process(true)
		queue_redraw()

var disabled: bool = false:
	set(value):
		disabled = value
		queue_redraw()
var _surface: StyleBoxFlat = StyleBoxFlat.new()
var _from_scale: float = 1.0
var _elapsed: float = 0.0


func _ready() -> void:
	_settle()


func _process(delta: float) -> void:
	if Tokens.reduced_motion:
		_settle()
		return
	_elapsed += delta
	var duration: float = Tokens.dur(Tokens.Motion.FAST)
	if _elapsed >= duration:
		_settle()
		return
	var target: float = Tokens.Layout.TILE_SELECTED_SCALE if selected else 1.0
	var curve: Vector2i = Tokens.Ease.SPRING if selected else Tokens.Ease.OUT
	var value: float = Tween.interpolate_value(
		_from_scale, target - _from_scale, _elapsed, duration, curve.x, curve.y
	)
	scale = Vector2.ONE * value


func _settle() -> void:
	scale = Vector2.ONE * (Tokens.Layout.TILE_SELECTED_SCALE if selected else 1.0)
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		_settle()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _exit_tree() -> void:
	selected = false
	_settle()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	_surface.bg_color = get_theme_color(&"TILE_SELECTED" if selected else &"TILE", &"Palette")
	_surface.set_corner_radius_all(int(radius))
	_surface.shadow_size = get_theme_constant(&"LOW", &"Elevation")
	_surface.shadow_offset.y = get_theme_constant(&"LOW_OFFSET_Y", &"Elevation")
	_surface.shadow_color = get_theme_color(&"LOW_COLOR", &"Elevation")
	_surface.border_color = get_theme_color(&"STROKE", &"Palette")
	_surface.set_border_width_all(Tokens.Action.OUTLINE_WIDTH if disabled else 0)
	draw_style_box(_surface, Rect2(Vector2.ZERO, size))
	var font: Font = get_theme_font(&"font", &"TileLetter")
	var font_size: int = mini(
		get_theme_font_size(&"font_size", &"TileLetter"),
		int(size.y * Tokens.Type.CELL_LETTER_RATIO)
	)
	if font_size <= 0:
		return
	var width: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(
		font,
		center + Vector2(-width / 2.0, baseline),
		letter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		get_theme_color(&"ON_PRIMARY" if selected else &"TEXT", &"Palette")
	)
