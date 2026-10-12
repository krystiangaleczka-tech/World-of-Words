class_name TextButton
extends ActionButton
## @api Low-emphasis action; inherited set_busy retains disabled-state compatibility.


func _kind() -> StringName:
	return &"text"


## @api Local pressed-underline endpoints, available to gallery geometry checks.
func underline_segment() -> PackedVector2Array:
	var text_size: Vector2 = get_theme_font("font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")
	)
	text_size.x = minf(text_size.x, maxf(size.x - Tokens.Space.M * 2, 0))
	var half: Vector2 = Rect2(Vector2.ZERO, text_size).get_center()
	var start: Vector2 = Rect2(Vector2.ZERO, size).get_center() + Vector2(-half.x, half.y)
	start.y = minf(start.y, size.y - Tokens.Space.S)
	return PackedVector2Array([start, start + Vector2(text_size.x, 0)])


func _draw() -> void:
	super._draw()
	if button_pressed:
		var segment: PackedVector2Array = underline_segment()
		draw_line(
			segment[0],
			segment[1],
			get_theme_color("font_pressed_color"),
			Tokens.Action.OUTLINE_WIDTH
		)
