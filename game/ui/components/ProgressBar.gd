class_name CatalogProgressBar
extends VBoxContainer
## @api Passive normalized progress with an explicit completion glyph and label.

const COMPLETE_KEY: String = "ui.progress.complete"
@export var value: float = 0:
	get:
		return _target
	set(next):
		set_value(next, false)
@export var tint: StringName = &"primary":
	set(next):
		if next not in [&"primary", &"bonus"]:
			return
		tint = next
		_refresh_theme()
@export var label_key: String = "":
	set(next):
		label_key = next
		_refresh_copy()
var displayed_value: float:
	get:
		return _displayed
var filling: bool:
	get:
		return _fill != null and _fill.is_running()
var _target: float = 0
var _displayed: float = 0
var _bar: ProgressBar
var _complete: TextureRect
var _label: Label
var _fill: Tween
var _catalog: LocaleCatalog = LocaleCatalog.new()
var _refreshing: bool = false


func _enter_tree() -> void:
	_catalog.register_all()
	_refresh_copy()
	_refresh_theme()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Label"
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.theme_type_variation = &"Caption"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.Space.S)
	add_child(row)
	_bar = ProgressBar.new()
	_bar.name = "Track"
	_bar.max_value = 1
	_bar.step = 0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(Tokens.Touch.MIN_TARGET, Tokens.Space.S)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_bar)
	_complete = TextureRect.new()
	_complete.name = "Complete"
	_complete.texture = preload("res://assets/icons/check.svg")
	_complete.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_complete.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_complete.custom_minimum_size = Vector2.ONE * Tokens.Space.L
	_complete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_complete)
	_show_progress(_displayed)
	_refresh_theme()


## @api Invalid floating-point input preserves target, displayed value and active tween.
func set_value(next: float, animate: bool = true) -> Error:
	if not is_finite(next):
		return ERR_INVALID_PARAMETER
	_cancel_fill()
	_target = clampf(next, 0, 1)
	if not animate or Tokens.reduced_motion or not is_node_ready() or _target == _displayed:
		_show_progress(_target)
		return OK
	_fill = create_tween().set_trans(Tokens.Ease.OUT.x).set_ease(Tokens.Ease.OUT.y)
	_fill.tween_method(_show_progress, _displayed, _target, Tokens.dur(Tokens.Motion.BASE))
	_fill.tween_callback(_finish_fill)
	set_process(true)
	return OK


func _show_progress(next: float) -> void:
	_displayed = next
	if _bar != null:
		_bar.value = next
	_refresh_copy()


func _finish_fill() -> void:
	_fill = null
	_show_progress(_target)
	set_process(false)


func _cancel_fill() -> void:
	if _fill != null:
		_fill.kill()
		_fill = null
	set_process(false)


func _refresh_copy() -> void:
	if _label == null:
		return
	var complete: bool = _displayed >= 1
	_complete.visible = complete
	var key: String = COMPLETE_KEY if complete else label_key
	_label.text = tr(key) if not key.is_empty() else ""
	_label.visible = not key.is_empty()
	accessibility_name = key
	accessibility_description = str(roundi(_displayed * 100))


func _refresh_theme() -> void:
	if _bar == null or _refreshing:
		return
	_refreshing = true
	for state: String in ["background", "fill"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(Tokens.Radius.FULL)
		style.bg_color = get_theme_color(
			(
				&"SURFACE_ALT"
				if state == "background"
				else (&"PRIMARY" if tint == &"primary" else &"BONUS")
			),
			&"Palette"
		)
		_bar.add_theme_stylebox_override(state, style)
	_complete.modulate = get_theme_color(&"PRIMARY" if tint == &"primary" else &"BONUS", &"Palette")
	_refreshing = false


func _process(_delta: float) -> void:
	if Tokens.reduced_motion:
		_cancel_fill()
		_show_progress(_target)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	_cancel_fill()
	_show_progress(_target)
	_catalog.unregister()
