class_name Toast
extends PanelContainer
## @api One passive transient message per viewport, with readability hold independent of motion.

const GROUP: StringName = &"catalog_toast"
const GLYPHS: Dictionary[StringName, Texture2D] = {
	&"info": preload("res://assets/icons/lightbulb.svg"),
	&"success": preload("res://assets/icons/check.svg"),
	&"error": preload("res://assets/icons/x.svg")
}
var text_key: String = ""
var kind: StringName = &"info"
var _label: Label
var _icon: TextureRect
var _timer: Timer
var _anchor: Control
var _fade: Tween
var _refreshing: bool = false
var _bounds_owner: Control
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _enter_tree() -> void:
	add_to_group(GROUP)
	_catalog.register_all()
	if _label != null:
		_connect_signals()
		_refresh_copy()
		_refresh_theme()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.Space.S)
	add_child(row)
	_icon = CatalogSurface.icon(GLYPHS[&"info"])
	row.add_child(_icon)
	_label = CatalogSurface.label()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = float(Tokens.Motion.TOAST_HOLD) / 1000.0
	add_child(_timer)
	_connect_signals()
	_refresh_theme()
	visible = false


## @api Invalid request preserves the displayed message and remaining hold.
func show_message(
	key: String, variant: StringName = &"info", glyph: Texture2D = null, anchor: Control = null
) -> Error:
	if key.strip_edges().is_empty() or not GLYPHS.has(variant):
		return ERR_INVALID_PARAMETER
	if not is_node_ready() or not is_inside_tree():
		return ERR_UNCONFIGURED
	if (
		anchor != null
		and (
			not anchor.is_inside_tree()
			or anchor.get_viewport() != get_viewport()
			or anchor == self
			or is_ancestor_of(anchor)
		)
	):
		return ERR_INVALID_PARAMETER
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: Toast = node as Toast
		if other != self and other.get_viewport() == get_viewport():
			other.hide_message()
	hide_message()
	text_key = key.strip_edges()
	kind = variant
	_anchor = anchor
	_icon.texture = glyph if glyph != null else GLYPHS[kind]
	_refresh_copy()
	_refresh_theme()
	visible = true
	_place()
	if not Tokens.reduced_motion:
		modulate.a = 0
		var rest: Vector2 = position
		position.y -= Tokens.Space.S
		_fade = create_tween().set_parallel(true).set_trans(Tokens.Ease.OUT.x).set_ease(
			Tokens.Ease.OUT.y
		)
		_fade.tween_property(self, "modulate:a", 1.0, Tokens.dur(Tokens.Motion.FAST))
		_fade.tween_property(self, "position", rest, Tokens.dur(Tokens.Motion.FAST))
	else:
		modulate.a = 1
	_timer.start()
	return OK


func hide_message() -> void:
	if _timer != null:
		_timer.stop()
	if _fade != null:
		_fade.kill()
		_fade = null
	visible = false


func _expire_message() -> void:
	_timer.stop()
	if not visible:
		return
	if _fade != null:
		_fade.kill()
	if Tokens.reduced_motion:
		hide_message()
	else:
		_fade = create_tween().set_trans(Tokens.Ease.IN.x).set_ease(Tokens.Ease.IN.y)
		_fade.tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.FAST))
		_fade.tween_callback(hide_message)


func _refresh_copy() -> void:
	if _label != null:
		_label.text = tr(text_key) if not text_key.is_empty() else ""
		accessibility_name = text_key
		_place()


func _refresh_theme() -> void:
	if _label == null or _refreshing:
		return
	_refreshing = true
	add_theme_stylebox_override(
		"panel", CatalogSurface.panel(self, Tokens.Space.M, Tokens.Radius.M, &"MID")
	)
	_icon.modulate = get_theme_color(
		&"SUCCESS" if kind == &"success" else (&"ERROR" if kind == &"error" else &"TEXT"),
		&"Palette"
	)
	_refreshing = false


func _place() -> void:
	if _label == null or not is_inside_tree():
		return
	var rect: Rect2 = CatalogSurface.parent_bounds(self)
	size.x = minf(rect.size.x, Tokens.Layout.MAX_CONTENT_WIDTH)
	size.y = get_combined_minimum_size().y
	position.x = rect.position.x + (rect.size.x - size.x) / 2
	var top: float = rect.position.y + Tokens.Layout.TOP_BAR_H + Tokens.Space.S
	if is_instance_valid(_anchor):
		var inverse: Transform2D = (
			(get_global_transform_with_canvas() * get_transform().affine_inverse()).affine_inverse()
		)
		top = (
			(inverse * _anchor.get_global_transform_with_canvas().origin).y
			- size.y
			- Tokens.Space.S
		)
	position.y = clampf(top, rect.position.y, maxf(rect.position.y, rect.end.y - size.y))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _connect_signals() -> void:
	_bounds_owner = CatalogSurface.bounds_owner(self)
	if _bounds_owner != null and not _bounds_owner.resized.is_connected(_place):
		_bounds_owner.resized.connect(_place)
	for pair: Array in [
		[resized, _place],
		[_label.minimum_size_changed, _place],
		[get_viewport().size_changed, _place],
		[_timer.timeout, _expire_message]
	]:
		if not (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).connect(pair[1])


func _exit_tree() -> void:
	hide_message()
	if _timer != null:
		for pair: Array in [
			[resized, _place],
			[_label.minimum_size_changed, _place],
			[get_viewport().size_changed, _place],
			[_timer.timeout, _expire_message]
		]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
	if is_instance_valid(_bounds_owner) and _bounds_owner.resized.is_connected(_place):
		_bounds_owner.resized.disconnect(_place)
	remove_from_group(GROUP)
	_catalog.unregister()
