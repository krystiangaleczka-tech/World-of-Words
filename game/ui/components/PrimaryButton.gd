class_name PrimaryButton
extends IconButton
## @api Plain P1 primary action; native Button input and translated accessible text.


func _ready() -> void:
	super._ready()
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var style: StyleBoxFlat = get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.bg_color = Tokens.Palette.PRIMARY
		add_theme_stylebox_override(state, style)
	var focus: StyleBoxFlat = get_theme_stylebox("focus").duplicate() as StyleBoxFlat
	focus.border_color = Tokens.Palette.TEXT
	add_theme_stylebox_override("focus", focus)
	for state: String in [
		"font_color",
		"font_hover_color",
		"font_focus_color",
		"font_pressed_color",
		"font_hover_pressed_color"
	]:
		add_theme_color_override(state, Tokens.Palette.ON_PRIMARY)
