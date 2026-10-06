class_name ScreenScaffold
extends Control
## @api Provisional safe-area screen root; body content is owned by the composing screen.

signal layout_class_changed(value: StringName)

@export var debug_insets: Rect2 = Rect2():
	set(value):
		debug_insets = value
		if is_node_ready():
			_refresh_layout()

var body: VBoxContainer
var layout_class: StringName = &"REGULAR"
var _safe: MarginContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Tokens.Palette.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe = MarginContainer.new()
	_safe.name = "Safe"
	add_child(_safe)
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", Tokens.Space.S)
	_safe.add_child(body)
	resized.connect(_refresh_layout)
	_refresh_layout()


## @api Viewport-space left/top/right/bottom insets, injectable for gallery/headless checks.
func apply_insets(insets: Rect2, viewport_size: Vector2) -> void:
	_safe.add_theme_constant_override(
		"margin_left", Tokens.Space.M + int(maxf(insets.position.x, 0))
	)
	_safe.add_theme_constant_override(
		"margin_top", Tokens.Space.M + int(maxf(insets.position.y, 0))
	)
	_safe.add_theme_constant_override("margin_right", Tokens.Space.M + int(maxf(insets.size.x, 0)))
	_safe.add_theme_constant_override("margin_bottom", Tokens.Space.M + int(maxf(insets.size.y, 0)))
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var usable: Vector2 = viewport_size - insets.position - insets.size
	var aspect: float = maxf(usable.y, 0) / maxf(usable.x, 1)
	var next: StringName = &"REGULAR"
	if aspect < Tokens.Layout.TABLET_MAX_ASPECT:
		next = &"TABLET"
	elif aspect < Tokens.Layout.COMPACT_MAX_ASPECT:
		next = &"COMPACT"
	if next != layout_class:
		layout_class = next
		layout_class_changed.emit(next)


func _refresh_layout() -> void:
	var insets: Rect2 = debug_insets
	if insets == Rect2() and DisplayServer.get_name() != "headless":
		var window: Rect2i = Rect2i(
			DisplayServer.window_get_position(), DisplayServer.window_get_size()
		)
		var usable: Rect2i = DisplayServer.get_display_safe_area().intersection(window)
		if window.size.x > 0 and window.size.y > 0 and usable.has_area():
			var scale: Vector2 = size / Vector2(window.size)
			insets = Rect2(
				Vector2(usable.position - window.position) * scale,
				Vector2(window.end - usable.end) * scale
			)
	apply_insets(insets, size)
