class_name WordPreview
extends Label
## @api Live word display. Result cues and motion follow in T-0107.


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size.y = Tokens.Type.PREVIEW + Tokens.Space.M
	add_theme_font_size_override("font_size", Tokens.Type.PREVIEW)
	add_theme_color_override("font_color", Tokens.Palette.TEXT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## @api Show the word spelled by the active chain's original tile indices.
func set_building(word: String) -> void:
	text = word


func clear() -> void:
	text = ""


func show_result(result: AttemptResult) -> void:
	text = result.word if result != null else ""
