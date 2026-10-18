class_name SettingsScreen
extends ScreenScaffold
## Explicit presentation only. Save owns persistence; callers own navigation/providers.

signal back_requested
signal setting_requested(key: StringName, value: Variant)
signal action_requested(action: StringName)

const POLICY_BINDING: Script = preload("res://features/settings/policy_binding.gd")
const SUPPORT: Script = preload("res://services/settings_support.gd")
const MONETIZATION: Script = preload("res://services/monetization.gd")
const LANGUAGE: Script = preload("res://services/settings_language.gd")
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
var language_sheet: Sheet
var language_options: Dictionary[String, TextButton] = {}
var language_retry: TextButton
var language_error: Label
var text_sheet: Sheet
var text_options: Array[TextButton] = []
var retry_button: TextButton
var write_error: Label
var policy_message: Label:
	get:
		return _policy.message
var policy_toast: Toast:
	get:
		return _policy.toast
var support_message: Label
var support_toast: Toast
var privacy_message: Label
var privacy_toast: Toast
var restore_message: Label
var restore_retry: TextButton
var restore_toast: Toast
var _policy: POLICY_BINDING = POLICY_BINDING.new()
var _language_content: VBoxContainer
var _language: LANGUAGE
var _text_content: VBoxContainer
var _failed_key: StringName = &""
var _failed_value: Variant
var _failed_revision: int = 0
var _runtime: RUNTIME
var _save: SAVE
var _column: VBoxContainer
var _privacy_available: bool = false
var _support_service: SUPPORT
var _support_bound: bool = false
var _support_dispatch: bool = false
var _support_command_error: Error = OK
var _support_error_revision: int = -1
var _support_attempt: int = 0
var _support_seen: String = ""
var _privacy_service: MONETIZATION
var _privacy_bound: bool = false
var _privacy_dispatch: bool = false
var _privacy_command_error: Error = OK
var _privacy_error_revision: int = -1
var _privacy_attempt: int = 0
var _privacy_seen: String = ""
var _restore_service: MONETIZATION
var _restore_bound: bool = false
var _restore_dispatch: bool = false
var _restore_command_error: Error = OK
var _restore_error_revision: int = -1
var _restore_attempt: int = 0
var _restore_seen: String = ""


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
	_failed_revision = _save.committed_view().revision
	if is_instance_valid(retry_button):
		retry_button.visible = true
		write_error.visible = true
	_refresh()
	if is_instance_valid(scroll):
		scroll.ensure_control_visible.call_deferred(retry_button)


func _retry_write() -> void:
	if is_instance_valid(_runtime):
		if _runtime.retry() in [OK, ERR_DOES_NOT_EXIST]:
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
		_failed_value = index
		if _runtime.set_value(&"text_scale", index) == OK:
			_clear_write_error()
		text_sheet.close()


## @api Explicit selector binding; unbound language rows still send named intent.
func bind_language(selector: Node) -> Error:
	if not selector is LANGUAGE or selector.snapshot().language.is_empty():
		return ERR_UNCONFIGURED
	_disconnect_language()
	_language = selector
	_connect_language()
	_refresh()
	return OK


func _connect_language() -> void:
	if is_inside_tree() and is_instance_valid(_language):
		if not _language.changed.is_connected(_language_changed):
			_language.changed.connect(_language_changed)


func _disconnect_language() -> void:
	if is_instance_valid(_language) and _language.changed.is_connected(_language_changed):
		_language.changed.disconnect(_language_changed)


func _build_language_controls() -> void:
	_language_content = VBoxContainer.new()
	_language_content.add_theme_constant_override("separation", Tokens.Space.S)
	language_sheet = Sheet.new()
	language_sheet.title_key = "settings.language.row"
	language_sheet.configure_content(_language_content)
	add_child(language_sheet)


func _open_language() -> void:
	for child: Node in _language_content.get_children():
		_language_content.remove_child(child)
		child.free()
	language_options.clear()
	var state: Dictionary = _language.snapshot()
	for choice: Dictionary in _language.choices():
		var option: TextButton = TextButton.new()
		option.text_key = choice.name_key
		if choice.name_key == "settings.language.other":
			option.value_text = choice.id
		option.sublabel_key = (
			"settings.language.selected"
			if not state.preview and choice.id == state.language
			else ""
		)
		option.highlighted = not state.preview and choice.id == state.language
		option.pressed.connect(_select_language.bind(choice.id))
		_language_content.add_child(option)
		language_options[choice.id] = option
	language_error = CatalogSurface.label(&"Caption")
	_language_content.add_child(language_error)
	language_retry = TextButton.new()
	language_retry.text_key = "settings.write.retry"
	language_retry.pressed.connect(_retry_language)
	_language_content.add_child(language_retry)
	_sync_language()
	language_sheet.open()


func _select_language(id: String) -> void:
	_language.select(id)


func _retry_language() -> void:
	_language.retry()


func _language_changed() -> void:
	_refresh()
	if _language.snapshot().pending.is_empty() and is_instance_valid(language_sheet):
		language_sheet.close()


func _sync_language() -> void:
	if not is_instance_valid(_language) or not is_instance_valid(language_sheet):
		return
	var state: Dictionary = _language.snapshot()
	var pending: bool = not state.pending.is_empty()
	language_sheet.dismissible = not pending
	if is_instance_valid(language_retry):
		language_retry.visible = pending and state.error != OK
		language_error.visible = language_retry.visible
		language_error.text = tr("settings.language.failed")
	for option: TextButton in language_options.values():
		option.disabled = pending
	rows[&"language"].trailing_value = tr(
		(
			"settings.language.preview_value"
			if state.preview
			else LANGUAGE.NAMES.get(state.language, "settings.language.other")
		)
	)
	if not LANGUAGE.NAMES.has(state.language) and not state.preview:
		rows[&"language"].trailing_value = state.language


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
	_connect_language()
	_connect_restore()
	_connect_privacy()
	_connect_support()
	if is_instance_valid(scroll):
		_reconcile_after_entry.call_deferred()


func _reconcile_after_entry() -> void:
	if not is_inside_tree():
		return
	if not _failed_key.is_empty():
		var view: Dictionary = _save.committed_view()
		var resolved: bool = view.sections.settings[_failed_key] == _failed_value
		var replaced: bool = (
			view.revision > _failed_revision and _save.get_setting(_failed_key) != _failed_value
		)
		if resolved or replaced:
			_clear_write_error()
	_refresh()


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
	_build_restore_controls()
	_section("privacy")
	_action(&"privacy_options")
	_build_privacy_controls()
	_action(&"privacy_policy")
	_policy.mount(self, rows[&"privacy_policy"], _save if is_instance_valid(_save) else null)
	_section("about")
	_action(&"licences")
	_action(&"support", &"value")
	_build_support_controls()
	information = CatalogSurface.label(&"Caption")
	_column.add_child(information)
	_build_apply_controls()
	_build_language_controls()
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
			_failed_value = value
		if _runtime.set_value(key, value) == OK:
			_clear_write_error()
	setting_requested.emit(key, value)
	_refresh()


func _request_action(key: StringName) -> void:
	if rows[key].is_visible_in_tree() and not rows[key].disabled and not rows[key].loading:
		if key == &"text_size" and is_instance_valid(_runtime):
			text_sheet.open()
		elif key == &"privacy_policy" and _policy.is_bound():
			_policy.request()
		elif key == &"support" and _support_bound:
			_dispatch_support()
		elif key == &"privacy_options" and _privacy_bound:
			_dispatch_privacy()
		elif key == &"restore" and _restore_bound:
			_dispatch_restore(false)
		elif key == &"language" and is_instance_valid(_language):
			_open_language()
		else:
			action_requested.emit(key)


func _back() -> void:
	if is_instance_valid(language_sheet) and language_sheet.handle_back():
		return
	if is_instance_valid(_language) and not _language.snapshot().pending.is_empty():
		return
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
	var language_pending: bool = (
		is_instance_valid(_language) and not _language.snapshot().pending.is_empty()
	)
	rows[&"text_size"].disabled = retry_button.visible or language_pending
	rows[&"language"].disabled = retry_button.visible
	for key: StringName in controls:
		rows[key].disabled = retry_button.visible or language_pending
		if controls[key] is Toggle:
			(controls[key] as Toggle).configure(values[key], SETTING_KEYS[key])
		else:
			(controls[key] as CatalogSlider).configure(float(values[key]), SETTING_KEYS[key], true)
	rows[&"text_size"].trailing_value = tr(
		["settings.display.scale100", "settings.display.scale115", "settings.display.scale130"][
			values.text_scale
		]
	)
	rows[&"language"].trailing_value = tr(
		"settings.language.polish" if values.language == "pl" else "settings.language.english"
	)
	_sync_language()
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
	_refresh_restore()
	_refresh_privacy()
	_refresh_support()
	_policy.refresh()


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
	_disconnect_language()
	_disconnect_restore()
	_disconnect_privacy()
	_disconnect_support()
	if is_instance_valid(_save) and _save.setting_changed.is_connected(_changed):
		_save.setting_changed.disconnect(_changed)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		_refresh_restore()
		_refresh_privacy()
		_refresh_support()
		_policy.refresh()
	elif what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_policy) and _policy.get_parent() == null:
			_policy.free()
		if is_instance_valid(_language_content):
			_language_content.free()
		if is_instance_valid(_text_content):
			_text_content.free()
		for control: Control in controls.values():
			if is_instance_valid(control):
				control.free()


## @api Explicit same-profile binding; unbound screens retain action intent.
func bind_restore(service: Node) -> Error:
	if _restore_dispatch:
		return ERR_BUSY
	if not service is MONETIZATION or not service.restore_owner_matches(_save):
		return ERR_UNCONFIGURED
	if is_instance_valid(_restore_service) and service != _restore_service:
		if _restore_service.restore_snapshot().state in [&"requested", &"settling"]:
			return ERR_BUSY
	if service != _restore_service:
		_restore_seen = ""
		_restore_attempt = 0
	_disconnect_restore()
	_restore_service = service
	_restore_bound = true
	_restore_command_error = OK
	_connect_restore()
	_refresh_restore()
	return OK


func _connect_restore() -> void:
	if is_inside_tree() and _restore_bound:
		if (
			not is_instance_valid(_restore_service)
			or not _restore_service.restore_owner_matches(_save)
		):
			_restore_lost()
			return
		if not _restore_service.restore_changed.is_connected(_restore_changed):
			_restore_service.restore_changed.connect(_restore_changed)
			_restore_service.tree_exiting.connect(_restore_lost)


func _disconnect_restore() -> void:
	if is_instance_valid(_restore_service):
		if _restore_service.restore_changed.is_connected(_restore_changed):
			_restore_service.restore_changed.disconnect(_restore_changed)
		if _restore_service.tree_exiting.is_connected(_restore_lost):
			_restore_service.tree_exiting.disconnect(_restore_lost)


func _restore_lost() -> void:
	_restore_command_error = OK
	if is_instance_valid(restore_toast):
		restore_toast.hide_message()
	_disconnect_restore()
	_restore_service = null
	_refresh_restore()


func _restore_changed() -> void:
	_restore_command_error = OK
	_refresh_restore()


func _build_restore_controls() -> void:
	restore_message = CatalogSurface.label(&"Caption")
	restore_message.visible = false
	_column.add_child(restore_message)
	restore_retry = TextButton.new()
	restore_retry.text_key = "settings.restore.retry_save"
	restore_retry.visible = false
	restore_retry.pressed.connect(_dispatch_restore.bind(true))
	_column.add_child(restore_retry)
	restore_toast = Toast.new()
	add_child(restore_toast)


func _dispatch_restore(settlement: bool) -> void:
	if _restore_dispatch or not is_instance_valid(_restore_service):
		return
	if settlement and (not restore_retry.is_visible_in_tree() or restore_retry.disabled):
		return
	_restore_dispatch = true
	restore_toast.hide_message()
	_restore_attempt += 1
	_restore_command_error = OK
	var error: Error = (
		_restore_service.retry_restore_settlement()
		if settlement
		else _restore_service.restore_purchases()
	)
	_restore_dispatch = false
	if is_instance_valid(_restore_service):
		if error != OK and _restore_service.restore_snapshot().state != &"settling":
			_restore_command_error = error
			_restore_error_revision = _restore_service.restore_snapshot().revision
	_refresh_restore()


func _refresh_restore() -> void:
	if not _restore_bound or not is_instance_valid(restore_message) or not rows.has(&"restore"):
		return
	if is_instance_valid(_restore_service) and not _restore_service.restore_owner_matches(_save):
		_restore_lost()
		return
	var data: Dictionary = (
		_restore_service.restore_snapshot()
		if is_instance_valid(_restore_service)
		else {
			"state": &"unavailable", "restored_count": -1, "error": ERR_UNAVAILABLE, "revision": 0
		}
	)
	if data.state == &"unavailable" or data.revision != _restore_error_revision:
		_restore_command_error = OK
	var key: String = ""
	match data.state:
		&"requested":
			key = "settings.restore.requested"
		&"settling":
			key = "settings.restore.settling"
		&"completed":
			key = (
				"settings.restore.empty"
				if data.restored_count == 0
				else "settings.restore.completed"
			)
		&"failed":
			key = "settings.restore.failed"
		&"unknown":
			key = "settings.restore.unknown"
		&"unavailable":
			key = "settings.restore.unavailable"
	if _restore_command_error != OK:
		key = (
			"settings.restore.busy"
			if _restore_command_error == ERR_BUSY
			else "settings.restore.failed"
		)
	rows[&"restore"].loading = data.state == &"requested"
	# Reuse the catalog loading icon slot to keep its spinner clear of wrapped text.
	rows[&"restore"].leading_icon = rows[&"restore"].icon if rows[&"restore"].loading else null
	rows[&"restore"].disabled = (
		_restore_dispatch or data.state in [&"requested", &"settling", &"unavailable"]
	)
	restore_retry.visible = data.state == &"settling"
	restore_retry.disabled = _restore_dispatch
	restore_message.visible = not key.is_empty()
	restore_message.text = tr(key) if not key.is_empty() else ""
	if key == "settings.restore.completed":
		restore_message.text = tr(key) % str(data.restored_count)
	var terminal: bool = (
		data.state in [&"completed", &"failed", &"unknown"]
		or _restore_command_error != OK
		or (data.state == &"settling" and data.error != OK)
	)
	var identity: int = (
		_restore_service.get_instance_id() if is_instance_valid(_restore_service) else 0
	)
	var fingerprint: String = "%s/%s/%s/%s" % [identity, data.revision, _restore_attempt, key]
	if terminal and is_visible_in_tree() and fingerprint != _restore_seen:
		var success: bool = data.state == &"completed" and _restore_command_error == OK
		var toast_key: String = (
			"settings.restore.success" if key == "settings.restore.completed" else key
		)
		if restore_toast.show_message(toast_key, &"success" if success else &"error") == OK:
			_restore_seen = fingerprint


## @api Explicit same-profile binding; service requirement owns bound visibility.
func bind_privacy(service: Node) -> Error:
	if _privacy_dispatch:
		return ERR_BUSY
	if not service is MONETIZATION or not service.privacy_owner_matches(_save):
		return ERR_UNCONFIGURED
	if is_instance_valid(_privacy_service) and service != _privacy_service:
		if _privacy_service.privacy_snapshot().state == &"requested":
			return ERR_BUSY
	if service != _privacy_service:
		_privacy_seen = ""
		_privacy_attempt = 0
	_disconnect_privacy()
	_privacy_service = service
	_privacy_bound = true
	_privacy_command_error = OK
	_connect_privacy()
	_refresh_privacy()
	return OK


func _connect_privacy() -> void:
	if is_inside_tree() and _privacy_bound:
		if (
			not is_instance_valid(_privacy_service)
			or not _privacy_service.privacy_owner_matches(_save)
		):
			_privacy_lost()
			return
		if not _privacy_service.privacy_changed.is_connected(_privacy_changed):
			_privacy_service.privacy_changed.connect(_privacy_changed)
			_privacy_service.tree_exiting.connect(_privacy_lost)


func _disconnect_privacy() -> void:
	if is_instance_valid(_privacy_service):
		if _privacy_service.privacy_changed.is_connected(_privacy_changed):
			_privacy_service.privacy_changed.disconnect(_privacy_changed)
		if _privacy_service.tree_exiting.is_connected(_privacy_lost):
			_privacy_service.tree_exiting.disconnect(_privacy_lost)


func _privacy_lost() -> void:
	_privacy_command_error = OK
	if is_instance_valid(privacy_toast):
		privacy_toast.hide_message()
	_disconnect_privacy()
	_privacy_service = null
	_refresh_privacy()


func _privacy_changed() -> void:
	_privacy_command_error = OK
	_refresh_privacy()


func _build_privacy_controls() -> void:
	privacy_message = CatalogSurface.label(&"Caption")
	privacy_message.visible = false
	_column.add_child(privacy_message)
	privacy_toast = Toast.new()
	add_child(privacy_toast)


func _dispatch_privacy() -> void:
	if _privacy_dispatch or not is_instance_valid(_privacy_service):
		return
	_privacy_dispatch = true
	privacy_toast.hide_message()
	_privacy_attempt += 1
	_privacy_command_error = OK
	var error: Error = _privacy_service.request_privacy_options()
	_privacy_dispatch = false
	if is_instance_valid(_privacy_service) and error != OK:
		_privacy_command_error = error
		_privacy_error_revision = _privacy_service.privacy_snapshot().revision
	_refresh_privacy()


func _refresh_privacy() -> void:
	if not _privacy_bound or not is_instance_valid(privacy_message):
		return
	if is_instance_valid(_privacy_service) and not _privacy_service.privacy_owner_matches(_save):
		_privacy_lost()
		return
	var data: Dictionary = (
		_privacy_service.privacy_snapshot()
		if is_instance_valid(_privacy_service)
		else {"state": &"unavailable", "available": false, "revision": 0}
	)
	if data.state == &"unavailable" or data.revision != _privacy_error_revision:
		_privacy_command_error = OK
	var key: String = "" if data.state == &"idle" else "settings.privacy." + str(data.state)
	if _privacy_command_error != OK:
		key = (
			"settings.privacy.busy"
			if _privacy_command_error == ERR_BUSY
			else "settings.privacy.failed"
		)
	var row: ListRow = rows[&"privacy_options"]
	row.visible = data.available
	row.loading = data.state == &"requested"
	row.leading_icon = row.icon if row.loading else null
	row.disabled = _privacy_dispatch or not data.available or row.loading
	privacy_message.visible = not key.is_empty()
	privacy_message.text = tr(key) if not key.is_empty() else ""
	var terminal: bool = (
		data.state in [&"completed", &"failed", &"unknown"] or _privacy_command_error != OK
	)
	var identity: int = (
		_privacy_service.get_instance_id() if is_instance_valid(_privacy_service) else 0
	)
	var fingerprint: String = "%s/%s/%s/%s" % [identity, data.revision, _privacy_attempt, key]
	if terminal and is_visible_in_tree() and fingerprint != _privacy_seen:
		var success: bool = data.state == &"completed" and _privacy_command_error == OK
		if privacy_toast.show_message(key, &"success" if success else &"error") == OK:
			_privacy_seen = fingerprint


## @api Explicit same-profile binding; the caller owns editable-draft handoff.
func bind_support(service: Node) -> Error:
	if _support_dispatch:
		return ERR_BUSY
	if not is_instance_valid(_save) or not service is SUPPORT or not service.owner_matches(_save):
		return ERR_UNCONFIGURED
	if is_instance_valid(_support_service) and service != _support_service:
		if _support_service.snapshot().state == &"requested":
			return ERR_BUSY
	if service != _support_service:
		_support_seen = ""
		_support_attempt = 0
	_disconnect_support()
	_support_service = service
	_support_bound = true
	_support_command_error = OK
	_connect_support()
	_refresh_support()
	return OK


func _connect_support() -> void:
	if is_inside_tree() and _support_bound:
		if (
			not is_instance_valid(_save)
			or not is_instance_valid(_support_service)
			or not _support_service.owner_matches(_save)
		):
			_support_lost()
			return
		if not _support_service.changed.is_connected(_support_changed):
			_support_service.changed.connect(_support_changed)
			_support_service.tree_exiting.connect(_support_lost)


func _disconnect_support() -> void:
	if is_instance_valid(_support_service):
		if _support_service.changed.is_connected(_support_changed):
			_support_service.changed.disconnect(_support_changed)
		if _support_service.tree_exiting.is_connected(_support_lost):
			_support_service.tree_exiting.disconnect(_support_lost)


func _support_lost() -> void:
	_support_command_error = OK
	if is_instance_valid(support_toast):
		support_toast.hide_message()
	_disconnect_support()
	_support_service = null
	_refresh_support()


func _support_changed() -> void:
	_support_command_error = OK
	_refresh_support()


func _build_support_controls() -> void:
	support_message = CatalogSurface.label(&"Caption")
	support_message.visible = false
	_column.add_child(support_message)
	support_toast = Toast.new()
	add_child(support_toast)


func _dispatch_support() -> void:
	if _support_dispatch or not is_instance_valid(_support_service):
		return
	_support_dispatch = true
	support_toast.hide_message()
	_support_attempt += 1
	_support_command_error = OK
	var error: Error = _support_service.request_draft()
	_support_dispatch = false
	if is_instance_valid(_support_service) and error != OK:
		_support_command_error = error
		_support_error_revision = _support_service.snapshot().revision
	_refresh_support()


func _refresh_support() -> void:
	if not _support_bound or not is_instance_valid(support_message):
		return
	if (
		is_instance_valid(_support_service)
		and (not is_instance_valid(_save) or not _support_service.owner_matches(_save))
	):
		_support_lost()
		return
	var data: Dictionary = (
		_support_service.snapshot()
		if is_instance_valid(_support_service)
		else {"state": &"unavailable", "available": false, "revision": 0}
	)
	if data.state == &"unavailable" or data.revision != _support_error_revision:
		_support_command_error = OK
	var key: String = "" if data.state == &"idle" else "settings.support." + str(data.state)
	if _support_command_error != OK:
		key = (
			"settings.support.busy"
			if _support_command_error == ERR_BUSY
			else "settings.support.failed"
		)
	var row: ListRow = rows[&"support"]
	row.loading = data.state == &"requested"
	row.leading_icon = row.icon if row.loading else null
	row.disabled = _support_dispatch or not data.available or row.loading
	support_message.visible = not key.is_empty()
	support_message.text = tr(key) if not key.is_empty() else ""
	var terminal: bool = data.state in [&"handed_off", &"failed"] or _support_command_error != OK
	var identity: int = (
		_support_service.get_instance_id() if is_instance_valid(_support_service) else 0
	)
	var fingerprint: String = "%s/%s/%s/%s" % [identity, data.revision, _support_attempt, key]
	if terminal and is_visible_in_tree() and fingerprint != _support_seen:
		var success: bool = data.state == &"handed_off" and _support_command_error == OK
		if support_toast.show_message(key, &"success" if success else &"error") == OK:
			_support_seen = fingerprint


## @api Explicit policy handoff binding; no auto-open on bind or refresh.
func bind_policy(service: Node) -> Error:
	if not is_instance_valid(_save):
		return ERR_UNCONFIGURED
	return _policy.bind(service, _save)
