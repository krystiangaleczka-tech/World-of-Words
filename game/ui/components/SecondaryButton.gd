class_name SecondaryButton
extends ActionButton
## @api Alternative action. The official video badge remains visible in every ad state.

const VIDEO: Texture2D = preload("res://assets/icons/video.svg")
@export var badge: StringName = &"":
	get:
		return _badge
	set(value):
		configure_badge(value)
var _badge: StringName = &""


## @api Empty/ad only. Invalid input preserves badge and layout.
func configure_badge(value: StringName) -> Error:
	if value not in [&"", &"ad"]:
		return ERR_INVALID_PARAMETER
	_badge = value
	_refresh_theme()
	update_minimum_size()
	queue_redraw()
	return OK


func _kind() -> StringName:
	return &"secondary"


func _ad_space() -> float:
	return Tokens.Space.L + Tokens.Space.S if _badge == &"ad" else 0.0


func _draw() -> void:
	super._draw()
	if _badge == &"ad":
		var rect: Rect2 = Rect2(
			Vector2(Tokens.Space.M, (size.y - _sublabel_height - Tokens.Space.L) / 2.0),
			Vector2.ONE * Tokens.Space.L
		)
		draw_texture_rect(VIDEO, rect, false, _palette(&"TEXT_MUTED" if disabled else &"PRIMARY"))
