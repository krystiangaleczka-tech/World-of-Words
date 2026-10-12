class_name CurrencyPill
extends IconButton
## @api Caller-owned balance presentation; native action is opt-in.

signal action_requested(kind: StringName)

const GLYPHS: Dictionary[StringName, Texture2D] = {
	&"coins": preload("res://assets/icons/coins.svg"),
	&"stars": preload("res://assets/icons/star.svg")
}
const LABELS: Dictionary[StringName, String] = {
	&"coins": "ui.currency.coins", &"stars": "ui.currency.stars"
}
@export var kind: StringName = &"coins":
	set(next):
		if not GLYPHS.has(next):
			return
		kind = next
		_refresh_copy()
		_refresh_theme()
@export var value: int = 0:
	get:
		return _target
	set(next):
		set_value(next, false)
@export var action_enabled: bool = false:
	set(next):
		action_enabled = next
		if loading:
			_was_disabled = not next
			disabled = true
		else:
			disabled = not next
		set_process_input(loading or not next)
		focus_mode = Control.FOCUS_ALL if next else Control.FOCUS_NONE
var displayed_value: int:
	get:
		return _displayed
var counting: bool:
	get:
		return _count != null and _count.is_running()
var _target: int = 0
var _displayed: int = 0
var _from: int = 0
var _count: Tween
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _enter_tree() -> void:
	_catalog.register_all()
	super._enter_tree()
	if _sublabel != null and not pressed.is_connected(_activate):
		pressed.connect(_activate)


func _ready() -> void:
	super._ready()
	action_enabled = action_enabled
	pressed.connect(_activate)
	_refresh_copy()
	_refresh_theme()


## @api Presentation clamps negatives; authoritative balances remain caller-owned integers.
func set_value(next: int, animate: bool = true) -> void:
	_cancel_count()
	_stop_motion()
	_target = maxi(next, 0)
	if not animate or Tokens.reduced_motion or not is_node_ready() or _displayed == _target:
		_displayed = _target
		_refresh_copy()
		return
	_from = _displayed
	_count = create_tween().set_trans(Tokens.Ease.OUT.x).set_ease(Tokens.Ease.OUT.y)
	var duration: float = Tokens.dur(
		int(
			minf(
				Tokens.Motion.SLOW + float(absi(_target - _from)) * Tokens.Motion.COUNT_UP_STEP,
				Tokens.Motion.COUNT_UP_MAX
			)
		)
	)
	_count.tween_method(_show_fraction, 0.0, 1.0, duration)
	_count.tween_callback(_finish_count)
	set_process(true)


func _show_fraction(fraction: float) -> void:
	_displayed = _target if fraction >= 1 else _from + int(float(_target - _from) * fraction)
	_refresh_copy()


func _check_disabled() -> void:
	# Passive balance availability suppresses input while retaining its presentation motion.
	if loading:
		_stop_motion()


func _finish_count() -> void:
	_count = null
	_displayed = _target
	_refresh_copy()
	if not Tokens.reduced_motion:
		_stop_motion()
		var half_fast: float = Tokens.dur(Tokens.Motion.FAST) / 2
		_motion = create_tween().set_trans(Tokens.Ease.SPRING.x).set_ease(Tokens.Ease.SPRING.y)
		_motion.tween_property(self, "scale", Vector2.ONE / Tokens.Action.PRESS_SCALE, half_fast)
		_motion.tween_property(self, "scale", Vector2.ONE, half_fast)
		set_process(true)


func _cancel_count() -> void:
	if _count != null:
		_count.kill()
		_count = null


func _activate() -> void:
	if action_enabled and not loading and not disabled:
		action_requested.emit(kind)


func _refresh_copy() -> void:
	text = str(_displayed)
	accessibility_name = LABELS[kind]
	accessibility_description = str(_displayed)
	if _sublabel != null:
		_sublabel.visible = false
		_layout_copy()
	if not loading:
		icon = GLYPHS[kind]


func _kind() -> StringName:
	return &"currency"


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	super._refresh_theme()
	_refreshing = true
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_constant_override("icon_max_width", Tokens.Space.L)
	add_theme_font_override("font", get_theme_font(&"NUMERIC", &"Type"))
	add_theme_font_size_override("font_size", get_theme_font_size(&"NUMERIC", &"Type"))
	var colour: Color = _palette(&"COIN" if kind == &"coins" else &"BONUS")
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.bg_color = _palette(&"SURFACE")
		style.set_border_width_all(Tokens.Space.XS if state == "focus" else 0)
		style.border_color = _palette(&"TEXT")
		if highlighted and state != "focus":
			style.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
			style.border_color = colour
		if state != "focus":
			style.shadow_size = Tokens.Elevation.MID
			style.shadow_offset.y = Tokens.Elevation.MID_OFFSET_Y
			style.shadow_color = get_theme_color(&"MID_COLOR", &"Elevation")
		add_theme_stylebox_override(state, style)
		add_theme_color_override("icon_%s_color" % state, colour)
	for suffix: String in ["", "_hover", "_pressed", "_hover_pressed", "_focus", "_disabled"]:
		add_theme_color_override("font%s_color" % suffix, colour)
	_refreshing = false


func _sync_state() -> void:
	super._sync_state()
	set_process_input(loading or not action_enabled)


func _input(event: InputEvent) -> void:
	super._input(event)
	if not action_enabled:
		disabled = true


func _process(delta: float) -> void:
	super._process(delta)
	if counting:
		if Tokens.reduced_motion:
			_cancel_count()
			_displayed = _target
			_refresh_copy()
		else:
			set_process(true)


func _exit_tree() -> void:
	_cancel_count()
	_displayed = _target
	_refresh_copy()
	if pressed.is_connected(_activate):
		pressed.disconnect(_activate)
	super._exit_tree()
	_catalog.unregister()
