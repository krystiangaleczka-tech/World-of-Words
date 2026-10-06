class_name TextButton
extends Button
## @api Provisional low-emphasis catalog action; native pressed signal carries user intent.

@export var text_key: String = "":
	set(value):
		text_key = value
		text = tr(text_key)

var _busy: bool = false
var _was_disabled: bool = false


func _ready() -> void:
	flat = true
	custom_minimum_size.y = Tokens.Touch.MIN_TARGET
	add_theme_font_size_override("font_size", Tokens.Type.LABEL)
	for state: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		add_theme_color_override(state, Tokens.Palette.PRIMARY)
	add_theme_color_override("font_disabled_color", Tokens.Palette.TEXT_MUTED)
	text = tr(text_key)


## @api Temporarily suppress presses, retaining the caller's initial disabled state.
func set_busy(busy: bool) -> void:
	if busy == _busy:
		return
	_busy = busy
	if busy:
		_was_disabled = disabled
		disabled = true
	else:
		disabled = _was_disabled


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		text = tr(text_key)


## @api Local pressed-underline endpoints, available to gallery geometry checks.
func underline_segment() -> PackedVector2Array:
	var text_size: Vector2 = get_theme_font("font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")
	)
	var half: Vector2 = Rect2(Vector2.ZERO, text_size).get_center()
	var start: Vector2 = Rect2(Vector2.ZERO, size).get_center() + Vector2(-half.x, half.y)
	return PackedVector2Array([start, start + Vector2(text_size.x, 0)])


func _draw() -> void:
	if button_pressed:
		var segment: PackedVector2Array = underline_segment()
		draw_line(segment[0], segment[1], get_theme_color("font_pressed_color"))
