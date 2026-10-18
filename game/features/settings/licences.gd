class_name LicencesScreen
extends ScreenScaffold
## Caller-owned offline credits. Existing Settings action intent selects this scene.

signal back_requested

const CREDITS: Script = preload("res://services/settings_credits.gd")
const KEYS: Dictionary[StringName, String] = {
	&"godot": "settings.licences.godot",
	&"godot-copyrights": "settings.licences.copyrights",
	&"godot-licenses": "settings.licences.third_party",
	&"inter": "settings.licences.inter",
	&"lucide": "settings.licences.lucide",
	&"audio": "settings.licences.audio",
	&"pl-sources": "settings.licences.sources"
}
var rows: Dictionary[StringName, ListRow] = {}
var scroll: ScrollContainer
var notice: Label
var back: IconButton
var selected_id: StringName = &""
var _detail: VBoxContainer
var _heading: Label
var _index: VBoxContainer
var _notices: Dictionary[StringName, String] = {}
var _index_scroll: int = 0


func _ready() -> void:
	super._ready()
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_index = VBoxContainer.new()
	_index.add_theme_constant_override("separation", Tokens.Space.S)
	column.add_child(_index)
	for entry: Dictionary in CREDITS.entries():
		var id: StringName = entry["id"]
		_notices[id] = entry["notice"]
		var row: ListRow = ListRow.new()
		row.title_key = KEYS[id]
		row.configure_trailing(null, &"chevron")
		row.pressed.connect(select_notice.bind(id))
		_index.add_child(row)
		rows[id] = row
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", Tokens.Space.M)
	_detail.visible = false
	column.add_child(_detail)
	_heading = CatalogSurface.label(&"Subtitle")
	_detail.add_child(_heading)
	notice = CatalogSurface.label()
	_detail.add_child(notice)
	back = IconButton.new()
	back.configure_icon(preload("res://assets/icons/arrow-left.svg"), "settings.main.back")
	back.pressed.connect(handle_back)
	var bar: TopBar = TopBar.new()
	bar.configure([back], "settings.about.licences", [])
	top_bar = bar


## @api Validation preserves the current notice and position on failure.
func select_notice(id: StringName) -> Error:
	if not is_node_ready():
		return ERR_UNCONFIGURED
	if not _notices.has(id):
		return ERR_INVALID_PARAMETER
	if selected_id.is_empty():
		_index_scroll = scroll.scroll_vertical
	selected_id = id
	notice.text = _notices[id]
	_index.hide()
	_detail.show()
	scroll.scroll_vertical = 0
	_heading.text = tr(KEYS[id])
	scroll.grab_focus()
	return OK


## @api Application Back first leaves detail; only the index requests navigation.
func handle_back() -> void:
	if not is_node_ready() or not is_visible_in_tree():
		return
	if selected_id.is_empty():
		back_requested.emit()
		return
	var previous: StringName = selected_id
	selected_id = &""
	_detail.hide()
	notice.text = ""
	_index.show()
	_restore_index.call_deferred(previous)


func _restore_index(id: StringName) -> void:
	if is_inside_tree() and selected_id.is_empty():
		scroll.scroll_vertical = _index_scroll
		if rows[id].is_visible_in_tree():
			rows[id].grab_focus()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_heading):
		if not selected_id.is_empty():
			_heading.text = tr(KEYS[selected_id])
