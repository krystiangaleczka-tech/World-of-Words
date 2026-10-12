class_name ScreenScaffold
extends Control
## @api Safe-area root. Public Body stack preserves composing-screen ownership.

signal layout_class_changed(value: StringName)

@export var debug_insets: Rect2 = Rect2():
	set(value):
		debug_insets = value
		if is_node_ready():
			_refresh_layout()
@export var background: Texture2D:
	set(value):
		background = value
		if is_instance_valid(_art):
			_art.texture = value
@export var top_bar: TopBar:
	set(value):
		if value == top_bar or value == bottom and value != null:
			return
		if value != null and (value == self or value.is_ancestor_of(self)):
			return
		if value != null and value.get_parent() != null and value.get_parent() != body:
			return
		var previous: TopBar = top_bar
		top_bar = value
		_detach(previous)
		_arrange_chrome()
@export var bottom: Control:
	set(value):
		if value == bottom or value == top_bar and value != null:
			return
		if value != null and (value == self or value.is_ancestor_of(self)):
			return
		if value != null and value.get_parent() != null and value.get_parent() != body:
			return
		var previous: Control = bottom
		bottom = value
		_detach(previous)
		_arrange_chrome()

var body: VBoxContainer
var layout_class: StringName = &"REGULAR"
var _safe: MarginContainer
var _background: ColorRect
var _art: TextureRect
var _viewport: Viewport
var _arranging: bool = false


func _enter_tree() -> void:
	if body != null:
		call_deferred("_connect_layout")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture = background
	add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe = MarginContainer.new()
	_safe.name = "Safe"
	add_child(_safe)
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", Tokens.Space.S)
	_safe.add_child(body)
	_refresh_background()
	_arrange_chrome()
	_connect_layout()


## @api Pure screen-pixel safe intersection converted to viewport-space edge insets.
static func screen_insets(safe: Rect2i, window: Rect2i, viewport: Vector2) -> Rect2:
	if window.size.x <= 0 or window.size.y <= 0 or viewport.x <= 0 or viewport.y <= 0:
		return Rect2()
	var usable: Rect2i = safe.intersection(window)
	if not usable.has_area():
		return Rect2()
	var scale_factor: Vector2 = viewport / Vector2(window.size)
	return Rect2(
		Vector2(usable.position - window.position) * scale_factor,
		Vector2(window.end - usable.end) * scale_factor
	)


## @api Inject left/top/right/bottom insets and classify without changing screen size.
func apply_insets(insets: Rect2, viewport_size: Vector2) -> void:
	if _safe == null:
		return
	var edges: Rect2 = Rect2(
		Vector2(maxf(insets.position.x, 0), maxf(insets.position.y, 0)),
		Vector2(maxf(insets.size.x, 0), maxf(insets.size.y, 0))
	)
	var usable: Vector2 = viewport_size - edges.position - edges.size
	var next: StringName = layout_class
	if usable.x > 0 and usable.y > 0:
		var aspect: float = usable.y / usable.x
		next = &"REGULAR"
		if aspect < Tokens.Layout.TABLET_MAX_ASPECT:
			next = &"TABLET"
		elif aspect < Tokens.Layout.COMPACT_MAX_ASPECT:
			next = &"COMPACT"
	var extra: float = 0
	if next == &"TABLET" and usable.x > 0:
		extra = maxf(
			(
				usable.x
				- ceili(edges.position.x)
				+ edges.position.x
				- ceili(edges.size.x)
				+ edges.size.x
				- Tokens.Space.M * 2
				- Tokens.Layout.MAX_CONTENT_WIDTH
			),
			0
		)
	var left_extra: int = floori(extra / 2.0)
	var right_extra: int = ceili(extra / 2.0)
	_safe.add_theme_constant_override(
		"margin_left", Tokens.Space.M + ceili(edges.position.x) + left_extra
	)
	_safe.add_theme_constant_override("margin_top", Tokens.Space.M + ceili(edges.position.y))
	_safe.add_theme_constant_override(
		"margin_right", Tokens.Space.M + ceili(edges.size.x) + right_extra
	)
	_safe.add_theme_constant_override("margin_bottom", Tokens.Space.M + ceili(edges.size.y))
	if next != layout_class:
		layout_class = next
		layout_class_changed.emit(next)


func _connect_layout() -> void:
	if not is_inside_tree():
		return
	_viewport = get_viewport()
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	if not _viewport.size_changed.is_connected(_refresh_layout):
		_viewport.size_changed.connect(_refresh_layout)
	if not body.child_order_changed.is_connected(_arrange_chrome):
		body.child_order_changed.connect(_arrange_chrome)
	_refresh_layout()


func _refresh_layout() -> void:
	var insets: Rect2 = debug_insets
	if (
		insets == Rect2()
		and not get_viewport() is SubViewport
		and DisplayServer.get_name() != "headless"
	):
		insets = screen_insets(
			DisplayServer.get_display_safe_area(),
			Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()),
			size
		)
	apply_insets(insets, size)


func _detach(control: Control) -> void:
	if is_instance_valid(control) and control.get_parent() == body and body != null:
		body.remove_child(control)


func _arrange_chrome() -> void:
	if body == null or _arranging:
		return
	_arranging = true
	for control: Control in [top_bar, bottom]:
		if is_instance_valid(control) and control.get_parent() == null:
			body.add_child(control)
	if is_instance_valid(top_bar) and top_bar.get_parent() == body:
		body.move_child(top_bar, 0)
	if is_instance_valid(bottom) and bottom.get_parent() == body:
		body.move_child(bottom, body.get_child_count() - 1)
	_arranging = false


func _refresh_background() -> void:
	if is_instance_valid(_background):
		_background.color = (
			get_theme_color(&"BG", &"Palette")
			if has_theme_color(&"BG", &"Palette")
			else Tokens.Palette.BG
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_background()


func _exit_tree() -> void:
	if resized.is_connected(_refresh_layout):
		resized.disconnect(_refresh_layout)
	if is_instance_valid(_viewport) and _viewport.size_changed.is_connected(_refresh_layout):
		_viewport.size_changed.disconnect(_refresh_layout)
	if body != null and body.child_order_changed.is_connected(_arrange_chrome):
		body.child_order_changed.disconnect(_arrange_chrome)
