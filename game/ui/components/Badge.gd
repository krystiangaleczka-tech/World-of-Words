class_name Badge
extends PanelContainer
## @api Passive dynamic count/state marker. Static copy comes from translated text_key.

const LOCK_KEY: String = "ui.badge.locked"
const NEW_KEY: String = "ui.badge.new"
const LOCK: Texture2D = preload("res://assets/icons/lock.svg")
@export var text: String = "":
	set(value):
		text = value
		_refresh_copy()
@export var text_key: String = "":
	set(value):
		text_key = value
		_refresh_copy()
@export var kind: StringName = &"info":
	get:
		return _kind
	set(value):
		if value not in [&"info", &"lock", &"new"]:
			return
		_kind = value
		_refresh_copy()
		_refresh_theme()
var _kind: StringName = &"info"
var _catalog: LocaleCatalog = LocaleCatalog.new()
var _label: Label
var _glyph: TextureRect
var _refreshing: bool = false


func _enter_tree() -> void:
	_catalog.register_all()
	_refresh_copy()
	_refresh_theme()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.Space.XS)
	add_child(row)
	_glyph = TextureRect.new()
	_glyph.name = "Lock"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.texture = LOCK
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.custom_minimum_size = Vector2.ONE * Tokens.Space.L
	row.add_child(_glyph)
	_label = Label.new()
	_label.name = "Caption"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.theme_type_variation = &"Caption"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	_refresh_copy()
	_refresh_theme()


## @api Invalid kind preserves the previous text and state atomically.
func configure(value: String, variant: StringName) -> Error:
	if variant not in [&"info", &"lock", &"new"]:
		return ERR_INVALID_PARAMETER
	text_key = ""
	text = value
	kind = variant
	return OK


func _refresh_copy() -> void:
	if _label == null:
		return
	var copy: String = tr(text_key) if not text_key.is_empty() else text
	if kind == &"new" and copy.is_empty():
		copy = tr(NEW_KEY)
	_label.text = copy
	_update_caption_width()
	_glyph.visible = kind == &"lock"
	_label.visible = not copy.is_empty()
	# Native accessibility properties translate their raw keys independently from Label.
	accessibility_description = ""
	if kind == &"lock":
		accessibility_name = LOCK_KEY
		accessibility_description = text_key if not text_key.is_empty() else text
	elif not text_key.is_empty():
		accessibility_name = text_key
	elif kind == &"new" and text.is_empty():
		accessibility_name = NEW_KEY
	else:
		accessibility_name = text


func _refresh_theme() -> void:
	if _label == null or _refreshing:
		return
	_refreshing = true
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = get_theme_color(&"BONUS" if kind == &"new" else &"PRIMARY", &"Palette")
	style.set_corner_radius_all(Tokens.Radius.FULL)
	style.content_margin_left = Tokens.Space.S
	style.content_margin_right = Tokens.Space.S
	style.content_margin_top = Tokens.Space.XS
	style.content_margin_bottom = Tokens.Space.XS
	add_theme_stylebox_override("panel", style)
	var foreground: Color = get_theme_color(&"ON_PRIMARY", &"Palette")
	_label.add_theme_color_override("font_color", foreground)
	_glyph.modulate = foreground
	_update_caption_width()
	_refreshing = false


func _update_caption_width() -> void:
	var natural: float = (
		_label
		. get_theme_font("font")
		. get_string_size(
			_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")
		)
		. x
	)
	# Preserve short count/state words at their intrinsic width; long copy may wrap.
	_label.custom_minimum_size.x = minf(natural, Tokens.Touch.MIN_TARGET)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	_catalog.unregister()
