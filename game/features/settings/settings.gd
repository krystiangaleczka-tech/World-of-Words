class_name SettingsScreen
extends ScreenScaffold
## Explicit presentation only. Save owns persistence; callers own navigation/providers.

signal back_requested
signal setting_requested(key: StringName, value: Variant)
signal action_requested(action: StringName)

const RUNTIME: Script = preload("res://services/settings_runtime.gd")
const SAVE: Script = preload("res://services/save.gd")
const ACTION_KEYS: Dictionary[StringName, String] = {
	&"text_size": "settings.display.text_size",
	&"language": "settings.language.row",
	&"shop": "settings.purchases.remove_forced_ads",
	&"restore": "settings.purchases.restore",
	&"privacy_options": "settings.privacy.options",
	&"privacy_policy": "settings.privacy.policy",
	&"licences": "settings.about.licences",
	&"support": "settings.about.support"
}
const SETTING_KEYS: Dictionary[StringName, String] = {
	&"sfx_volume": "settings.sound.effects",
	&"music_volume": "settings.sound.music",
	&"haptics_enabled": "settings.sound.haptics",
	&"reduced_motion": "settings.display.reduced_motion",
	&"high_contrast": "settings.display.high_contrast"
}
var rows: Dictionary[StringName, ListRow] = {}
var controls: Dictionary[StringName, Control] = {}
var scroll: ScrollContainer
var back: IconButton
var information: Label
var text_sheet: Sheet
var text_options: Array[TextButton] = []
var retry_button: TextButton
var write_error: Label
var _text_content: VBoxContainer
var _failed_key: StringName = &""
var _runtime: RUNTIME
var _save: SAVE
var _column: VBoxContainer
var _privacy_available: bool = false


func configure(save: Node) -> Error:
	if is_inside_tree():
		return ERR_BUSY
	if not save is SAVE or not save.is_loaded():
		return ERR_UNCONFIGURED
	_save = save
	return OK


## @api Explicit application binding; the unbound screen keeps intent-only behavior.
func bind_runtime(runtime: Node) -> Error:
	if not runtime is RUNTIME or runtime.snapshot().is_empty():
		return ERR_UNCONFIGURED
	_disconnect_runtime()
	_runtime = runtime
	_connect_runtime()
	return OK


func _connect_runtime() -> void:
	if is_inside_tree() and is_instance_valid(_runtime):
		if not _runtime.changed.is_connected(_runtime_changed):
			_runtime.changed.connect(_runtime_changed)
			_runtime.write_failed.connect(_runtime_failed)


func _disconnect_runtime() -> void:
	if is_instance_valid(_runtime) and _runtime.changed.is_connected(_runtime_changed):
		_runtime.changed.disconnect(_runtime_changed)
		_runtime.write_failed.disconnect(_runtime_failed)


func _clear_write_error() -> void:
	_failed_key = &""
	if is_instance_valid(retry_button):
		retry_button.visible = false
		write_error.visible = false
	_refresh()


func _runtime_changed() -> void:
	_refresh()


func _runtime_failed(_error: Error) -> void:
	if is_instance_valid(retry_button):
		retry_button.visible = true
		write_error.visible = true
	_refresh()
	if is_instance_valid(scroll):
		scroll.ensure_control_visible.call_deferred(retry_button)


func _retry_write() -> void:
	if is_instance_valid(_runtime):
		if _runtime.retry() == OK:
			_clear_write_error()


func _build_apply_controls() -> void:
	write_error = CatalogSurface.label(&"Caption")
	write_error.text = tr("settings.write.error")
	write_error.visible = false
	_column.add_child(write_error)
	retry_button = TextButton.new()
	retry_button.text_key = "settings.write.retry"
	retry_button.visible = false
	retry_button.pressed.connect(_retry_write)
	_column.add_child(retry_button)
	_text_content = VBoxContainer.new()
	_text_content.add_theme_constant_override("separation", Tokens.Space.S)
	for index: int in range(3):
		var option: TextButton = TextButton.new()
		option.text_key = [
			"settings.display.scale100", "settings.display.scale115", "settings.display.scale130"
		][index]
		option.pressed.connect(_choose_text_size.bind(index))
		_text_content.add_child(option)
		text_options.append(option)
	text_sheet = Sheet.new()
	text_sheet.title_key = "settings.display.text_size"
	text_sheet.configure_content(_text_content)
	add_child(text_sheet)


func _choose_text_size(index: int) -> void:
	if is_instance_valid(_runtime) and text_sheet.state != &"closed":
		_failed_key = &"text_scale"
		if _runtime.set_value(&"text_scale", index) == OK:
			_clear_write_error()
		text_sheet.close()


func snapshot() -> Dictionary:
	if not is_instance_valid(_save) or not _save.is_loaded():
		return {}
	return _save.committed_view().sections.settings.duplicate(true)


func set_privacy_options_available(available: bool) -> void:
	_privacy_available = available
	_refresh()


func _enter_tree() -> void:
	super._enter_tree()
	_connect_save()
	_connect_runtime()
	if is_instance_valid(scroll):
		_refresh.call_deferred()


func _ready() -> void:
	super._ready()
	scroll = ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", Tokens.Space.S)
	scroll.add_child(_column)
	_section("sound")
	_setting(&"sfx_volume", true)
	_setting(&"music_volume", true)
	_setting(&"haptics_enabled", false)
	_section("display")
	_setting(&"reduced_motion", false)
	_setting(&"high_contrast", false)
	_action(&"text_size", &"value")
	_section("language")
	_action(&"language", &"value")
	_section("purchases")
	_action(&"shop")
	_action(&"restore")
	_section("privacy")
	_action(&"privacy_options")
	_action(&"privacy_policy")
	_section("about")
	_action(&"licences")
	_action(&"support", &"value")
	information = CatalogSurface.label(&"Caption")
	_column.add_child(information)
	_build_apply_controls()
	back = IconButton.new()
	back.configure_icon(preload("res://assets/icons/arrow-left.svg"), "settings.main.back")
	back.pressed.connect(_back)
	var bar: TopBar = TopBar.new()
	bar.configure([back], "settings.main.title", [])
	top_bar = bar
	_connect_save()
	_connect_runtime()
	_refresh()


func _section(name_value: String) -> void:
	var heading: Label = CatalogSurface.label(&"Caption")
	heading.text = tr("settings.section." + name_value)
	heading.name = "Section_" + name_value
	heading.set_meta(&"copy_key", "settings.section." + name_value)
	_column.add_child(heading)


func _row(key: StringName, title: String) -> ListRow:
	var row: ListRow = ListRow.new()
	row.name = String(key)
	row.title_key = title
	_column.add_child(row)
	rows[key] = row
	return row


func _setting(key: StringName, slider: bool) -> void:
	var row: ListRow = _row(key, SETTING_KEYS[key])
	if slider:
		var control: CatalogSlider = CatalogSlider.new()
		control.configure(0.0, SETTING_KEYS[key], true)
		controls[key] = control
		row.configure_trailing(control, &"slider")
		control.preview_requested.connect(_request_setting.bind(key))
	else:
		var control: Toggle = Toggle.new()
		control.configure(false, SETTING_KEYS[key])
		controls[key] = control
		row.configure_trailing(control, &"toggle")
		control.value_changed.connect(_request_setting.bind(key))


func _action(key: StringName, variant: StringName = &"chevron") -> void:
	var row: ListRow = _row(key, ACTION_KEYS[key])
	row.configure_trailing(null, variant)
	row.pressed.connect(_request_action.bind(key))


func _request_setting(value: Variant, key: StringName) -> void:
	if not rows[key].is_visible_in_tree() or rows[key].disabled or rows[key].loading:
		return
	if is_instance_valid(_runtime):
		if not is_instance_valid(retry_button) or not retry_button.visible:
			_failed_key = key
		if _runtime.set_value(key, value) == OK:
			_clear_write_error()
	setting_requested.emit(key, value)
	_refresh()


func _request_action(key: StringName) -> void:
	if rows[key].is_visible_in_tree() and not rows[key].disabled and not rows[key].loading:
		if key == &"text_size" and is_instance_valid(_runtime):
			text_sheet.open()
		else:
			action_requested.emit(key)


func _back() -> void:
	if is_instance_valid(text_sheet) and text_sheet.handle_back():
		return
	if back.is_visible_in_tree() and not back.disabled:
		back_requested.emit()


func _refresh() -> void:
	if controls.is_empty() or not is_instance_valid(information):
		return
	if is_instance_valid(write_error):
		write_error.text = tr("settings.write.error")
	var values: Dictionary = snapshot()
	if values.is_empty():
		for row: ListRow in rows.values():
			row.disabled = true
		return
	rows[&"text_size"].disabled = retry_button.visible
	for key: StringName in controls:
		rows[key].disabled = retry_button.visible
		if controls[key] is Toggle:
			(controls[key] as Toggle).disabled = retry_button.visible
			(controls[key] as Toggle).configure(values[key], SETTING_KEYS[key])
		else:
			(controls[key] as CatalogSlider).set_available(not retry_button.visible)
			(controls[key] as CatalogSlider).configure(float(values[key]), SETTING_KEYS[key], true)
	rows[&"text_size"].trailing_value = tr(
		["settings.display.scale100", "settings.display.scale115", "settings.display.scale130"][
			values.text_scale
		]
	)
	rows[&"language"].trailing_value = tr(
		"settings.language.polish" if values.language == "pl" else "settings.language.english"
	)
	var view: Dictionary = _save.committed_view()
	var owned: bool = view.sections.monetization.remove_forced_ads
	rows[&"shop"].disabled = owned
	rows[&"shop"].configure_trailing(null, &"value" if owned else &"chevron")
	rows[&"shop"].trailing_value = tr("settings.purchases.owned") if owned else ""
	rows[&"privacy_options"].visible = _privacy_available
	var identity: String = view.sections.meta.install_id.left(8)
	rows[&"support"].trailing_value = identity
	information.text = (
		tr("settings.about.version")
		% [str(ProjectSettings.get_setting("application/config/version", "")), identity]
	)
	for child: Node in _column.get_children():
		if child is Label and child.has_meta(&"copy_key"):
			(child as Label).text = tr(child.get_meta(&"copy_key"))


func _changed(key: StringName) -> void:
	if key == _failed_key:
		_clear_write_error()
	_refresh()


func _connect_save() -> void:
	if (
		is_inside_tree()
		and is_instance_valid(_save)
		and not _save.setting_changed.is_connected(_changed)
	):
		_save.setting_changed.connect(_changed)


func _exit_tree() -> void:
	super._exit_tree()
	_disconnect_runtime()
	if is_instance_valid(_save) and _save.setting_changed.is_connected(_changed):
		_save.setting_changed.disconnect(_changed)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()
	elif what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_text_content):
			_text_content.free()
		for control: Control in controls.values():
			if is_instance_valid(control):
				control.free()
