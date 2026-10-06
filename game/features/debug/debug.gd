extends ScreenScaffold
## Debug-only diagnostics; reset always targets the services Nav injected before mounting.

const SAVE_SCRIPT = preload("res://services/save.gd")
const CONTENT_SCRIPT = preload("res://services/content.gd")
const NAV_SCRIPT = preload("res://services/nav.gd")
const TEXT_BUTTON: PackedScene = preload("res://ui/components/TextButton.tscn")

var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _nav: NAV_SCRIPT
var _translations: Array[Translation] = []
var _pending: bool = false
var _failed: bool = false
var _title: Label
var _app: Label
var _version: Label
var _status: Label
var _confirm: TextButton
var _cancel: TextButton


## @api Supply the same services as Nav, before entering the scene tree.
func configure(save: SAVE_SCRIPT, content: CONTENT_SCRIPT, nav: NAV_SCRIPT) -> void:
	assert(not is_inside_tree())
	_save = save
	_content = content
	_nav = nav


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	if _save == null:
		_save = Save
		_content = Content
		_nav = Nav
	super._ready()
	_register_copy()
	_title = _label("Title", Tokens.Type.TITLE)
	_app = _label("AppVersion", Tokens.Type.BODY)
	_version = _label("ContentVersion", Tokens.Type.BODY)
	_status = _label("Status", Tokens.Type.CAPTION)
	_button("Reset", "debug.shell.reset", request_reset)
	_confirm = _button("Confirm", "debug.shell.confirm", confirm_reset)
	_cancel = _button("Cancel", "debug.shell.cancel", cancel_reset)
	_button("Home", "debug.shell.home", _go_home)
	_refresh_copy()
	_show_confirmation(false)


## @api First press only opens confirmation; no Save mutation.
func request_reset() -> void:
	if not OS.is_debug_build() or _save == null or not _save.is_loaded():
		return
	_failed = false
	_show_confirmation(true)
	_refresh_copy()


## @api Close confirmation without changing Save or navigation.
func cancel_reset() -> void:
	if not OS.is_debug_build():
		return
	_failed = false
	_show_confirmation(false)
	_refresh_copy()


## @api A second explicit press commits reset, then returns to Level 1.
func confirm_reset() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	if not _pending or _save == null or _nav == null:
		return ERR_UNCONFIGURED
	_confirm.set_busy(true)
	var error: Error = _save.debug_reset()
	if error == OK:
		error = _nav.go_to_level(1)
	if error != OK:
		_confirm.set_busy(false)
		_failed = true
		_refresh_copy()
	return error


func _go_home() -> void:
	if OS.is_debug_build() and _nav != null:
		_nav.go_home()


func _show_confirmation(pending: bool) -> void:
	_pending = pending
	if is_instance_valid(_confirm):
		_confirm.visible = pending
		_cancel.visible = pending


func _label(node_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Tokens.Palette.TEXT)
	body.add_child(label)
	return label


func _button(node_name: String, key: String, handler: Callable) -> TextButton:
	var button: TextButton = TEXT_BUTTON.instantiate() as TextButton
	button.name = node_name
	button.text_key = key
	button.pressed.connect(handler)
	body.add_child(button)
	return button


func _register_copy() -> void:
	var csv: FileAccess = FileAccess.open("res://locale/debug.csv", FileAccess.READ)
	var header: PackedStringArray = csv.get_csv_line()
	for column: int in range(1, header.size()):
		var translation: Translation = Translation.new()
		translation.locale = header[column]
		_translations.append(translation)
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() != header.size():
			continue
		for index: int in _translations.size():
			_translations[index].add_message(row[0], row[index + 1])
	for translation: Translation in _translations:
		TranslationServer.add_translation(translation)


func _refresh_copy() -> void:
	if not is_instance_valid(_title):
		return
	_title.text = tr("debug.shell.title")
	_app.text = (
		"%s: %s"
		% [
			tr("debug.shell.app_version"),
			ProjectSettings.get_setting("application/config/version", "")
		]
	)
	_version.text = "%s: %s" % [tr("debug.shell.content_version"), _content.content_version()]
	_status.text = (
		tr("debug.shell.error") if _failed else (tr("debug.shell.prompt") if _pending else "")
	)
	_status.add_theme_color_override(
		"font_color", Tokens.Palette.ERROR if _failed else Tokens.Palette.TEXT_MUTED
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()


func _exit_tree() -> void:
	for translation: Translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
