class_name IconButton
extends ActionButton
## @api Native icon action. P1 callers retain labelled text_key until screen migration.

@export var a11y_label_key: String = "":
	set(value):
		if icon != null and value.strip_edges().is_empty() and not a11y_label_key.is_empty():
			return
		a11y_label_key = value.strip_edges()
		_refresh_copy()
@export var icon_size: StringName = &"M":
	set(value):
		if value not in [&"S", &"M"]:
			return
		icon_size = value
		_refresh_theme()


## @api Validate entire icon configuration before changing any displayed/accessibility state.
func configure_icon(glyph: Texture2D, key: String, preset: StringName = &"M") -> Error:
	if glyph == null or key.strip_edges().is_empty() or preset not in [&"S", &"M"]:
		return ERR_INVALID_PARAMETER
	# The label is established before mounting the glyph, including pre-ready exports.
	a11y_label_key = key.strip_edges()
	icon = glyph
	icon_size = preset
	_refresh_copy()
	_refresh_theme()
	return OK


func _kind() -> StringName:
	return &"icon"


func _refresh_copy() -> void:
	if a11y_label_key.is_empty():
		if loading:
			_saved_icon = null
		elif icon != null:
			icon = null
		super._refresh_copy()
		tooltip_text = ""
		return
	if _sublabel != null:
		_sublabel.visible = false
		_layout_copy()
	var key: String = a11y_label_key if not a11y_label_key.is_empty() else text_key
	var label: String = tr(key) if not key.is_empty() else ""
	if text != "":
		text = ""
	# Godot translates native accessibility properties when reading them.
	accessibility_name = key
	tooltip_text = label


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	super._refresh_theme()
	_refreshing = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_color_override("icon_normal_color", _palette(&"PRIMARY"))
	add_theme_constant_override(
		"icon_max_width", Tokens.Space.L if icon_size == &"S" else Tokens.Space.XL
	)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.set_border_width_all(0)
		style.bg_color = _palette(&"SURFACE")
		if state in ["pressed", "hover_pressed"]:
			style.bg_color = _palette(&"PRIMARY")
		elif state in ["hover", "disabled"]:
			style.bg_color = _palette(&"SURFACE_ALT")
		if highlighted and state in ["normal", "hover"]:
			style.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
			style.border_color = _palette(&"PRIMARY")
		if state == "focus":
			style.draw_center = false
			style.set_border_width_all(Tokens.Space.XS)
			style.border_color = _palette(&"PRIMARY")
		add_theme_stylebox_override(state, style)
	for state: String in ["pressed", "hover_pressed"]:
		add_theme_color_override("font_%s_color" % state, _palette(&"ON_PRIMARY"))
		add_theme_color_override("icon_%s_color" % state, _palette(&"ON_PRIMARY"))
	_refreshing = false


func _draw() -> void:
	if a11y_label_key.is_empty():
		super._draw()
	elif loading:
		draw_arc(
			size / 2,
			Tokens.Space.S,
			_angle,
			_angle + TAU * (1.0 - 1.0 / Tokens.Space.XS),
			Tokens.Space.M,
			_palette(&"TEXT_MUTED"),
			Tokens.Action.OUTLINE_WIDTH,
			true
		)
