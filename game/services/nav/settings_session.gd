extends Node
## Owns the settings bindings for a loaded game and its current Settings visit.

const SETTINGS: PackedScene = preload("res://features/settings/settings_screen.tscn")
const LICENCES: PackedScene = preload("res://features/settings/licences_screen.tscn")
const LICENCES_ROUTE: Script = preload("res://features/settings/licences_route.gd")

var _save: Node
var _runtime: SettingsRuntime
var _language: SettingsLanguage
var _screen: SettingsScreen
var _route: Node


func configure(save: Node, content: Node, host: Control, root: String, reload: Callable) -> Error:
	_save = save
	_language = SettingsLanguage.new()
	add_child(_language)
	var error: Error = _language.configure(save, content, reload, root, OS.is_debug_build())
	if error != OK:
		return error
	_runtime = SettingsRuntime.new()
	add_child(_runtime)
	return _runtime.configure(save, host)


func build_screen() -> Control:
	var visit: Control = Control.new()
	visit.name = "SettingsVisit"
	visit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var settings: SettingsScreen = SETTINGS.instantiate() as SettingsScreen
	var licences: LicencesScreen = LICENCES.instantiate() as LicencesScreen
	licences.hide()
	var error: Error = settings.configure(_save)
	if error == OK:
		error = settings.bind_runtime(_runtime)
	if error == OK:
		error = settings.bind_language(_language)
	if error != OK:
		push_error("Settings bindings unavailable: %s" % error_string(error))
	visit.add_child(settings)
	visit.add_child(licences)
	return visit


func bind_visit(visit: Control, back: Callable) -> void:
	_screen = visit.get_node("Settings") as SettingsScreen
	_screen.back_requested.connect(back)
	# Provider-backed rows are added to the player flow when their transports are available.
	for key: StringName in [&"shop", &"restore", &"privacy_policy", &"support"]:
		_screen.rows[key].hide()
	var column: Node = _screen.rows[&"shop"].get_parent()
	for heading: String in ["Section_purchases", "Section_privacy"]:
		(column.get_node(heading) as Label).hide()
	_route = LICENCES_ROUTE.new()
	visit.add_child(_route)
	var error: Error = _route.configure(_screen, visit.get_node("Licences"))
	if error != OK:
		_screen.rows[&"licences"].disabled = true
		push_error("Offline licences unavailable: %s" % error_string(error))


func handle_licences_back() -> bool:
	return is_instance_valid(_route) and _route.is_inside_tree() and _route.handle_back()


func can_leave() -> bool:
	return (
		_language.snapshot().pending.is_empty()
		and (not is_instance_valid(_screen) or not _screen.retry_button.visible)
	)
