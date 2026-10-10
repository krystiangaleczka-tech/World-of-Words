extends ScreenScaffold
## Debug-only diagnostics; reset always targets the services Nav injected before mounting.

const PL: Translation = preload("res://locale/debug.pl.translation")
const EN: Translation = preload("res://locale/debug.en.translation")

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
var _selected: int = 0
var _slot_label: Label
var _answers: Label
var _previous: TextButton
var _next: TextButton
var _open: TextButton
var _show_answers: TextButton
var _complete: TextButton
var _level_failed: bool = false
var _buttons: Array[TextButton] = []
var _handlers: Array[Callable] = []


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
	_create_level_tools()
	_button("Reset", "debug.shell.reset", request_reset)
	_confirm = _button("Confirm", "debug.shell.confirm", confirm_reset)
	_cancel = _button("Cancel", "debug.shell.cancel", cancel_reset)
	_button("Home", "debug.shell.home", _go_home)
	_refresh_copy()
	_show_confirmation(false)


func _create_level_tools() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SlotSelector"
	row.add_theme_constant_override("separation", Tokens.Space.S)
	body.add_child(row)
	_previous = _button("Previous", "debug.level.previous", select_previous)
	_previous.reparent(row)
	_slot_label = _label("SelectedSlot", Tokens.Type.BODY)
	_slot_label.reparent(row)
	_slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next = _button("Next", "debug.level.next", select_next)
	_next.reparent(row)
	_open = _button("OpenLevel", "debug.level.open", open_selected)
	_show_answers = _button("ShowAnswers", "debug.level.answers", toggle_answers)
	_answers = _label("Answers", Tokens.Type.CAPTION)
	_answers.visible = false
	_complete = _button("CompleteLevel", "debug.level.complete", complete_selected)
	_selected = clampi(_nav.level_slot(), 1, _content.slot_count()) if _content.is_loaded() else 0


## @api Read the currently selected shipped slot; zero when content is unavailable.
func selected_slot() -> int:
	return _selected


func select_previous() -> void:
	_select(_selected - 1)


func select_next() -> void:
	_select(_selected + 1)


func _select(slot: int) -> void:
	if not OS.is_debug_build() or not _content.is_loaded():
		return
	_selected = clampi(slot, 1, _content.slot_count())
	_answers.visible = false
	_level_failed = false
	_refresh_copy()


func _selected_level() -> LevelData:
	return _content.level_for_slot(_selected) if _selected > 0 else null


## @api Toggle only the declared answers for this selection; no Save writes.
func toggle_answers() -> void:
	if not OS.is_debug_build():
		return
	if _answers.visible:
		_answers.visible = false
		return
	var level: LevelData = _selected_level()
	_level_failed = level == null
	if level != null:
		var words: PackedStringArray = PackedStringArray()
		for index: int in level.word_count():
			words.append(level.word(index))
		_answers.text = "%s: %s" % [tr("debug.level.answers"), ", ".join(words)]
		_answers.visible = true
	_refresh_copy()


## @api Navigate to the selected slot without altering progress.
func open_selected() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	var error: Error = _nav.go_to_level(_selected)
	if error != OK:
		_level_failed = true
		_refresh_copy()
	return error


## @api Explicit debug completion may skip forward, never regress saved campaign progress.
func complete_selected() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	var level: LevelData = _selected_level()
	if level == null:
		_level_failed = true
		_refresh_copy()
		return ERR_FILE_NOT_FOUND
	var original: Dictionary = _save.get_section(&"progress")
	var section: Dictionary = original.duplicate(true)
	var language: String = str(_save.get_setting(&"language"))
	var state: Dictionary = section["by_lang"].get(
		language, SaveSchema.LANGUAGE_STATE.duplicate(true)
	)
	if (
		_selected < int(state.get("current_slot", 1))
		and _selected > int(state.get("highest_completed_slot", 0))
	):
		return _level_error(ERR_INVALID_PARAMETER)
	var error: Error = OK
	if _selected > int(state.get("current_slot", 1)):
		state["current_slot"] = _selected
		state["level_state"] = null
		section["by_lang"][language] = state
		error = _save.set_section(&"progress", section)
	if error == OK:
		error = _save.flush()
	if error != OK:
		_save.set_section(&"progress", original)
	else:
		error = _nav.go_to_level(_selected)
	if error != OK:
		return _level_error(error)
	var screen: LevelScreen = _nav.mounted_screen() as LevelScreen
	if screen == null:
		return ERR_UNAVAILABLE
	var cells: Array[Vector2i] = []
	for index: int in level.word_count():
		for cell: Vector2i in level.word_cells(index):
			if cell not in cells:
				cells.append(cell)
	# Earlier slots already have durable completion history. Hydrate that board up to
	# the final cell, then use the controller for the final reveal and normal effects.
	# This avoids save_level(), which correctly rejects an earlier active snapshot.
	if _selected <= int(state.get("highest_completed_slot", 0)):
		for index: int in maxi(cells.size() - 1, 0):
			screen.controller.get_board().reveal_cell(cells[index])
	var attempts: int = cells.size() + 1
	for _index: int in attempts:
		if screen.controller.is_complete():
			break
		if not screen.controller.hint():
			error = ERR_FILE_CANT_WRITE
			break
	return error if error != OK else (OK if screen.controller.is_complete() else ERR_UNAVAILABLE)


func _level_error(error: Error) -> Error:
	_level_failed = true
	_refresh_copy()
	return error


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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Tokens.Palette.TEXT)
	body.add_child(label)
	return label


func _button(node_name: String, key: String, handler: Callable) -> TextButton:
	var button: TextButton = TEXT_BUTTON.instantiate() as TextButton
	button.name = node_name
	button.text_key = key
	button.pressed.connect(handler)
	_buttons.append(button)
	_handlers.append(handler)
	body.add_child(button)
	return button


func _register_copy() -> void:
	for source: Translation in [PL, EN]:
		var translation: Translation = source.duplicate() as Translation
		_translations.append(translation)
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
		tr("debug.level.error")
		if _level_failed
		else (
			tr("debug.shell.error") if _failed else (tr("debug.shell.prompt") if _pending else "")
		)
	)
	if is_instance_valid(_slot_label):
		_slot_label.text = tr("debug.level.slot_n") % _selected
		var unavailable: bool = _selected == 0 or not _content.is_loaded()
		_previous.disabled = unavailable or _selected <= 1
		_next.disabled = unavailable or _selected >= _content.slot_count()
		for button: TextButton in [_open, _show_answers, _complete]:
			button.disabled = unavailable
		if _answers.visible:
			var level: LevelData = _selected_level()
			if level != null:
				var words: PackedStringArray = PackedStringArray()
				for index: int in level.word_count():
					words.append(level.word(index))
				_answers.text = "%s: %s" % [tr("debug.level.answers"), ", ".join(words)]
	_status.add_theme_color_override(
		"font_color",
		Tokens.Palette.ERROR if _failed or _level_failed else Tokens.Palette.TEXT_MUTED
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()


func _exit_tree() -> void:
	for index: int in _buttons.size():
		if (
			is_instance_valid(_buttons[index])
			and _buttons[index].pressed.is_connected(_handlers[index])
		):
			_buttons[index].pressed.disconnect(_handlers[index])
	_buttons.clear()
	_handlers.clear()
	for translation: Translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
