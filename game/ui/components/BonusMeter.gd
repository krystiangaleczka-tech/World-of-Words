class_name BonusMeter
extends CatalogAction
## @api Caller-configured bonus progress; native full intent never grants rewards.

signal open_requested
const OPEN_KEY: String = "ui.bonus.open"
const TITLE_KEY: String = "ui.bonus.title"
# Largest binary32 value below one survives native real_t helpers without rounding up.
const PARTIAL_CEILING: float = 0.9999999403953552
const GIFT: Texture2D = preload("res://assets/icons/gift.svg")
var count: int:
	get:
		return _count
var target: int:
	get:
		return _target
var state: StringName:
	get:
		if _already:
			return &"already"
		if _progress != null and _progress.filling:
			return &"filling"
		if _full():
			return &"full"
		return &"highlighted" if highlighted else &"normal"
var _count: int = 0
var _target: int = 0
var _gift: TextureRect
var _progress: CatalogProgressBar
var _completion: Tween
var _pulse: Tween
var _already_marker: Badge
var _already: bool = false
var _shown_full: bool = false


## @api Invalid configuration preserves all displayed state and active work.
func configure(next: int, goal: int) -> Error:
	if next < 0 or goal <= 0:
		return ERR_INVALID_PARAMETER
	_target = goal
	return set_count(next, false)


## @api Caller supplies balances; exact counts never convert through float.
func set_count(next: int, animate: bool = true) -> Error:
	if next < 0 or _target <= 0:
		return ERR_INVALID_PARAMETER
	_cancel_completion()
	_stop_pulse()
	_count = next
	if _progress != null:
		_progress.set_value(_ratio(), animate)
		if _progress.filling:
			_completion = create_tween()
			_completion.tween_interval(Tokens.dur(Tokens.Motion.BASE))
			_completion.tween_callback(_fill_finished)
	_refresh_copy()
	_refresh_available()
	_refresh_theme()
	return OK


func _ratio() -> float:
	return (
		1.0
		if _count >= _target and _target > 0
		else (minf(float(_count) / _target, PARTIAL_CEILING) if _target > 0 else 0.0)
	)


func _full() -> bool:
	return (
		_target > 0 and _count >= _target and _progress != null and _progress.displayed_value >= 1
	)


func _build_content() -> void:
	_gift = CatalogSurface.icon(GIFT, Tokens.Space.XL)
	column.add_child(_gift)
	super._build_content()
	_title_label.theme_type_variation = &"Numeric"
	_progress = CatalogProgressBar.new()
	_progress.tint = &"bonus"
	column.add_child(_progress)
	_progress.set_value(_ratio(), false)
	_already_marker = Badge.new()
	_already_marker.text_key = "ui.bonus.already"
	_already_marker.visible = false
	column.add_child(_already_marker)
	_connect_open()


func _connect_open() -> void:
	if not pressed.is_connected(_on_open):
		pressed.connect(_on_open)


func _on_open() -> void:
	if _full() and not disabled and not loading:
		open_requested.emit()


func _refresh_copy() -> void:
	text = ""
	accessibility_name = OPEN_KEY if _full() else TITLE_KEY
	accessibility_description = "%d / %d" % [_count, _target]
	if _sublabel != null:
		_sublabel.visible = false
	if _title_label != null:
		_title_label.text = "%d / %d" % [_count, _target]
		_subtitle_label.text = tr("ui.bonus.open") if _full() else ""
		_subtitle_label.visible = _full()


func _refresh_available() -> void:
	var active: bool = _full() and not disabled and not loading
	button_mask = MOUSE_BUTTON_MASK_LEFT if active else 0
	focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	set_process_shortcut_input(active)
	if not active and has_focus():
		release_focus()
	if _shown_full != _full():
		_shown_full = _full()
		_refresh_copy()
		_refresh_theme()


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	super._refresh_theme()
	_refreshing = true
	_title_label.add_theme_color_override("font_color", _palette(&"BONUS"))
	_gift.modulate = _palette(&"BONUS")
	if _full() or highlighted or _already:
		for variant: String in ["normal", "hover"]:
			var box: StyleBoxFlat = get_theme_stylebox(variant).duplicate() as StyleBoxFlat
			box.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
			box.border_color = _palette(&"BONUS")
			add_theme_stylebox_override(variant, box)
	_refreshing = false


func _fill_finished() -> void:
	_completion = null
	_refresh_available()
	_pop_icon()


func _pop_icon() -> void:
	_stop_pulse()
	if Tokens.reduced_motion:
		return
	_gift.pivot_offset = _gift.size / 2
	var half_fast: float = Tokens.dur(Tokens.Motion.FAST) / 2.0
	_pulse = create_tween().set_trans(Tokens.Ease.SPRING.x).set_ease(Tokens.Ease.SPRING.y)
	_pulse.tween_property(_gift, "scale", Vector2.ONE / Tokens.Action.PRESS_SCALE, half_fast)
	_pulse.tween_property(_gift, "scale", Vector2.ONE, half_fast)
	_pulse.tween_callback(_stop_pulse)
	set_process(true)


## @api Already-found feedback uses DESIGN twice-fast pulse; reduction preserves static state.
func pulse_already() -> Error:
	if not is_inside_tree() or not is_node_ready():
		return ERR_UNCONFIGURED
	_cancel_completion()
	_stop_motion()
	_stop_pulse()
	_already = true
	_already_marker.visible = true
	_refresh_theme()
	if Tokens.reduced_motion:
		return OK
	var half_fast: float = Tokens.dur(Tokens.Motion.FAST) / 2.0
	_pulse = create_tween().set_trans(Tokens.Ease.IN_OUT.x).set_ease(Tokens.Ease.IN_OUT.y)
	for repeat: int in 2:
		_pulse.tween_property(self, "scale", Vector2.ONE * Tokens.Action.ALREADY_SCALE, half_fast)
		_pulse.tween_property(self, "scale", Vector2.ONE, half_fast)
	_pulse.tween_callback(_stop_pulse)
	set_process(true)
	return OK


func _cancel_completion() -> void:
	if _completion != null:
		_completion.kill()
		_completion = null


func _stop_pulse(preserve_already: bool = false) -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	var was_already: bool = _already
	if was_already:
		scale = Vector2.ONE
	if not preserve_already:
		_already = false
		if _already_marker != null:
			_already_marker.visible = false
	if _gift != null:
		_gift.scale = Vector2.ONE
	if was_already and not preserve_already:
		_refresh_theme()


func _press_down() -> void:
	if _already:
		_stop_pulse()
	super._press_down()


func _press_up() -> void:
	if _already:
		_stop_pulse()
	super._press_up()


func _sync_state() -> void:
	if _already:
		_stop_pulse()
	super._sync_state()


func _check_disabled() -> void:
	if disabled:
		_stop_pulse()
	super._check_disabled()


func _process(delta: float) -> void:
	super._process(delta)
	if Tokens.reduced_motion:
		_stop_pulse(_already)
	elif _pulse != null and _pulse.is_running():
		set_process(true)


func _enter_tree() -> void:
	super._enter_tree()
	if _progress != null:
		_connect_open()


func _exit_tree() -> void:
	_cancel_completion()
	_stop_pulse()
	if pressed.is_connected(_on_open):
		pressed.disconnect(_on_open)
	super._exit_tree()
