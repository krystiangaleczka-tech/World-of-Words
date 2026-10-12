class_name Toggle
extends ActionButton
## @api Native boolean intent with required translated name and noncolour on cue.

signal value_changed(value: bool)
const CHECK: Texture2D = preload("res://assets/icons/check.svg")
@export var value: bool:
	get:
		return button_pressed
	set(next):
		set_pressed_no_signal(next)
		_refresh_copy()
		_refresh_theme()
		queue_redraw()
@export var a11y_label_key: String = "":
	set(next):
		if next.strip_edges().is_empty():
			return
		a11y_label_key = next.strip_edges()
		_refresh_copy()
		_refresh_available()
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _init() -> void:
	toggle_mode = true


## @api Entire request validates before changing value or label.
func configure(next: bool, key: String) -> Error:
	if key.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	a11y_label_key = key
	value = next
	return OK


func _enter_tree() -> void:
	_catalog.register_all()
	super._enter_tree()
	if is_node_ready():
		_connect_toggle()


func _ready() -> void:
	toggle_mode = true
	super._ready()
	var width: float = Tokens.Touch.MIN_TARGET * 2.0
	custom_minimum_size = Vector2(width, Tokens.Touch.MIN_TARGET)
	_connect_toggle()
	_refresh_available()


func _connect_toggle() -> void:
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)


func _on_toggled(next: bool) -> void:
	_refresh_copy()
	_refresh_theme()
	queue_redraw()
	value_changed.emit(next)


func _refresh_copy() -> void:
	text = ""
	if _sublabel != null:
		_sublabel.visible = false
	accessibility_name = a11y_label_key
	accessibility_description = "ui.toggle.on" if value else "ui.toggle.off"
	tooltip_text = tr(a11y_label_key) if not a11y_label_key.is_empty() else ""


func _refresh_available() -> void:
	var active: bool = not a11y_label_key.is_empty() and not disabled and not loading
	button_mask = MOUSE_BUTTON_MASK_LEFT if active else 0
	focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	set_process_shortcut_input(active)
	if not active and has_focus():
		release_focus()


func _sync_state() -> void:
	super._sync_state()
	if is_node_ready():
		set_process_input(true)
		_refresh_available()


func _input(event: InputEvent) -> void:
	super._input(event)
	_refresh_available()


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	_refreshing = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = CatalogSurface.panel(self, Tokens.Space.XS, Tokens.Radius.FULL)
		box.bg_color = _palette(&"PRIMARY" if value and state != "disabled" else &"SURFACE_ALT")
		if state == "focus" or highlighted:
			box.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
			box.border_color = _palette(&"TEXT")
		if state == "focus":
			box.draw_center = false
		add_theme_stylebox_override(state, box)
	_refreshing = false


func _draw() -> void:
	var center: Vector2 = Vector2(
		size.x - Tokens.Touch.MIN_TARGET / 2.0 if value else Tokens.Touch.MIN_TARGET / 2.0,
		size.y / 2
	)
	draw_circle(center, Tokens.Touch.MIN_TARGET / 2.0 - Tokens.Space.XS, _palette(&"SURFACE"))
	if value:
		draw_texture_rect(
			CHECK,
			Rect2(center - Vector2.ONE * Tokens.Space.L / 2, Vector2.ONE * Tokens.Space.L),
			false,
			_palette(&"PRIMARY")
		)


func _exit_tree() -> void:
	if toggled.is_connected(_on_toggled):
		toggled.disconnect(_on_toggled)
	_catalog.unregister()
	super._exit_tree()


func _check_disabled() -> void:
	super._check_disabled()
	_refresh_available()
