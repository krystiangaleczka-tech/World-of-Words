class_name StatePanel
extends PanelContainer
## @api Explanatory presentation; optional action emits intent, never performs retries.

signal action_requested
const GLYPHS: Dictionary[StringName, Texture2D] = {
	&"offline": preload("res://assets/icons/route.svg"),
	&"error": preload("res://assets/icons/x.svg"),
	&"empty": preload("res://assets/icons/map-pinned.svg"),
	&"unavailable": preload("res://assets/icons/lock.svg")
}
var kind: StringName = &"empty"
var title_key: String = ""
var body_key: String = ""
var action_key: String = ""
var _icon: TextureRect
var _title: Label
var _body: Label
var _action: PrimaryButton
var _refreshing: bool = false
var _catalog: LocaleCatalog = LocaleCatalog.new()


## @api Validate all fields before replacing copy/state/action.
func configure(variant: StringName, title: String, body: String, action: String = "") -> Error:
	if not GLYPHS.has(variant) or title.strip_edges().is_empty() or body.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	kind = variant
	title_key = title.strip_edges()
	body_key = body.strip_edges()
	action_key = action.strip_edges()
	_refresh_copy()
	_refresh_theme()
	return OK


func _enter_tree() -> void:
	_catalog.register_all()
	if _action != null:
		_connect_action()
		_refresh_copy()
		_refresh_theme()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.Space.M)
	add_child(column)
	_icon = CatalogSurface.icon(GLYPHS[kind], Tokens.Space.XL)
	column.add_child(_icon)
	_title = CatalogSurface.label(&"Subtitle")
	column.add_child(_title)
	_body = CatalogSurface.label()
	column.add_child(_body)
	_action = PrimaryButton.new()
	column.add_child(_action)
	_connect_action()
	_refresh_copy()
	_refresh_theme()


func _refresh_copy() -> void:
	if _title == null:
		return
	_title.text = tr(title_key) if not title_key.is_empty() else ""
	_body.text = tr(body_key) if not body_key.is_empty() else ""
	_action.text_key = action_key
	_action.visible = not action_key.is_empty()
	_icon.texture = GLYPHS[kind]
	accessibility_name = title_key
	accessibility_description = body_key


func _refresh_theme() -> void:
	if _icon == null or _refreshing:
		return
	_refreshing = true
	add_theme_stylebox_override("panel", CatalogSurface.panel(self))
	_icon.modulate = get_theme_color(&"ERROR" if kind == &"error" else &"TEXT", &"Palette")
	_refreshing = false


func _connect_action() -> void:
	if not _action.pressed.is_connected(_on_action):
		_action.pressed.connect(_on_action)


func _on_action() -> void:
	action_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	if _action.pressed.is_connected(_on_action):
		_action.pressed.disconnect(_on_action)
	_catalog.unregister()
