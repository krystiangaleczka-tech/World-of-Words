class_name NavTab
extends CatalogAction
## @api Caller-selected navigation intent; unbuilt features are hidden.

const LOCK: Texture2D = preload("res://assets/icons/lock.svg")
const CHECK: Texture2D = preload("res://assets/icons/check.svg")
@export var label_key: String:
	get:
		return text_key
	set(next):
		if not next.strip_edges().is_empty():
			text_key = next.strip_edges()
@export var locked_label_key: String = "":
	set(next):
		locked_label_key = next
		_refresh_copy()
@export var selected: bool = false:
	set(next):
		selected = next
		_refresh_copy()
		_refresh_theme()
@export var locked: bool = false:
	set(next):
		locked = next
		_refresh_copy()
		_refresh_theme()
		_refresh_available()
@export var implemented: bool = true:
	set(next):
		implemented = next
		visible = next
		_refresh_available()
var _glyph: Texture2D
var _icon: TextureRect
var _check: TextureRect
var _new: Badge


## @api Invalid icon or label preserves existing native/accessibility state.
func configure(glyph: Texture2D, key: String, lock_key: String = "") -> Error:
	if glyph == null or key.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	_glyph = glyph
	label_key = key
	locked_label_key = lock_key
	_refresh_copy()
	_refresh_available()
	return OK


func _build_content() -> void:
	_icon = CatalogSurface.icon(null, Tokens.Space.XL)
	column.add_child(_icon)
	super._build_content()
	_title_label.theme_type_variation = &"Caption"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check = CatalogSurface.icon(CHECK)
	column.add_child(_check)
	_new = Badge.new()
	_new.kind = &"new"
	_new.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_new)


func _refresh_copy() -> void:
	super._refresh_copy()
	if _icon == null:
		return
	_icon.texture = LOCK if locked else _glyph
	_subtitle_label.text = (
		tr(locked_label_key) if locked and not locked_label_key.is_empty() else ""
	)
	_subtitle_label.visible = locked and not locked_label_key.is_empty()
	_check.visible = selected and not locked
	_new.visible = highlighted and not locked
	accessibility_description = (
		locked_label_key if locked else ("ui.nav.selected" if selected else "")
	)
	tooltip_text = tr(label_key) if not label_key.is_empty() else ""


func _refresh_available() -> void:
	var active: bool = (
		_glyph != null
		and not label_key.is_empty()
		and implemented
		and not locked
		and not disabled
		and not loading
	)
	button_mask = MOUSE_BUTTON_MASK_LEFT if active else 0
	focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	set_process_shortcut_input(active)
	if not active and has_focus():
		release_focus()
	if _new != null:
		_new.visible = highlighted and not locked


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	super._refresh_theme()
	_refreshing = true
	var focus: StyleBoxFlat = get_theme_stylebox("focus").duplicate() as StyleBoxFlat
	focus.draw_center = false
	add_theme_stylebox_override("focus", focus)
	if selected and not locked:
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var box: StyleBoxFlat = get_theme_stylebox(state).duplicate() as StyleBoxFlat
			box.bg_color = _palette(&"PRIMARY" if not disabled else &"SURFACE_ALT")
			add_theme_stylebox_override(state, box)
	var foreground: Color = _palette(
		&"ON_PRIMARY" if selected and not locked and not disabled else &"TEXT"
	)
	_title_label.add_theme_color_override("font_color", foreground)
	_icon.modulate = foreground
	_check.modulate = foreground
	_refreshing = false
