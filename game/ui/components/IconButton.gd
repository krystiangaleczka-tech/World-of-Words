class_name IconButton
extends Button
## @api Provisional labeled catalog action with a native accessible button role.

@export var text_key: String = "":
	set(value):
		text_key = value
		_refresh_text()
var _copy: LevelCopy = LevelCopy.new()


func _enter_tree() -> void:
	_copy.register()
	_refresh_text()


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * Tokens.Touch.MIN_TARGET
	clip_text = false
	add_theme_font_size_override("font_size", Tokens.Type.LABEL)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Tokens.Palette.SURFACE
		if state == "hover" or state == "disabled":
			style.bg_color = Tokens.Palette.SURFACE_ALT
		elif state == "pressed":
			style.bg_color = Tokens.Palette.PRIMARY
		style.set_corner_radius_all(Tokens.Radius.FULL)
		style.content_margin_left = Tokens.Space.M
		style.content_margin_right = Tokens.Space.M
		style.content_margin_top = Tokens.Space.S
		style.content_margin_bottom = Tokens.Space.S
		if state == "focus":
			style.draw_center = false
			style.set_border_width_all(Tokens.Space.XS)
			style.border_color = Tokens.Palette.PRIMARY
		add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
		add_theme_color_override(state, Tokens.Palette.PRIMARY)
	add_theme_color_override("font_disabled_color", Tokens.Palette.TEXT_MUTED)
	add_theme_color_override("font_pressed_color", Tokens.Palette.ON_PRIMARY)
	add_theme_color_override("font_hover_pressed_color", Tokens.Palette.ON_PRIMARY)
	_refresh_text()


func _refresh_text() -> void:
	text = tr(text_key) if not text_key.is_empty() else ""
	accessibility_name = text


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func _exit_tree() -> void:
	_copy.unregister()
