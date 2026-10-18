extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const SERVICE: Script = preload("res://services/settings_policy.gd")
const MEMORY: Script = preload("res://tests/integration/test_level_hud.gd")
const CLOCK: Script = preload("res://tests/integration/test_iap_settlement.gd")
const FIXTURE: Script = preload("res://tests/integration/test_settings_policy.gd")
const SCENE: PackedScene = preload("res://features/settings/settings_screen.tscn")
const ID: String = "12345678-1234-4234-8234-123456789abc"
var save: SAVE
var service: SERVICE
var browser: FIXTURE.Browser
var _nodes: Array[Node] = []
var _views: Array[SubViewport] = []
var _locale: String
var _pseudo: bool
var _motion: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true
	save = SAVE.new()
	_nodes = [save]
	add_child(save)
	save.initialize(CLOCK.FixedClock.new())
	save.configure(MEMORY.MemoryStorage.new(), func() -> String: return ID)
	assert_eq(save.load(), OK)
	_new_service()


func _new_service() -> void:
	service = SERVICE.new()
	browser = FIXTURE.Browser.new()
	for node: Node in [browser, service]:
		_nodes.append(node)
		add_child(node)
	assert_eq(service.configure(save, browser.open), OK)


func after_each() -> void:
	for view: SubViewport in _views:
		view.free()
	_views.clear()
	_nodes.reverse()
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _view(size: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	_views.append(view)
	return view


func _screen(view: SubViewport, bound: bool = true) -> SettingsScreen:
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(save), OK)
	if bound:
		assert_eq(screen.bind_policy(service), OK)
	view.add_child(screen)
	return screen


func _settle() -> void:
	for frame: int in range(5):
		await get_tree().process_frame


func test_binding_and_legacy_intent_require_actual_same_owner() -> void:
	var screen: SettingsScreen = _screen(_view(), false)
	watch_signals(screen)
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_signal_emitted_with_parameters(screen, "action_requested", [&"privacy_policy"])
	assert_eq(browser.calls.size(), 0)
	assert_eq(screen.bind_policy(null), ERR_UNCONFIGURED)
	assert_eq(screen.bind_policy(save), ERR_UNCONFIGURED)
	var foreign: SAVE = SAVE.new()
	foreign.initialize(CLOCK.FixedClock.new())
	foreign.configure(MEMORY.MemoryStorage.new())
	assert_eq(foreign.load(), OK)
	var other: SettingsScreen = SCENE.instantiate()
	assert_eq(other.configure(foreign), OK)
	assert_eq(other.bind_policy(service), ERR_UNCONFIGURED)
	other.free()
	foreign.free()
	assert_eq(screen.bind_policy(service), OK)
	assert_eq(screen.bind_policy(null), ERR_UNCONFIGURED)
	assert_eq(browser.calls.size(), 0)
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_eq(browser.calls.size(), 1)
	assert_signal_emit_count(screen, "action_requested", 1)


func test_language_only_handoff_and_save_is_unchanged() -> void:
	var screen: SettingsScreen = _screen(_view())
	var before: Dictionary = save.committed_view()
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_eq(browser.calls.size(), 1)
	assert_eq(browser.calls[0], "pl")
	assert_eq(screen.rows[&"privacy_policy"].title_key, "settings.privacy.policy")
	assert_eq(screen.policy_message.text, tr("settings.policy.handed_off"))
	assert_eq(screen.policy_toast.text_key, "settings.policy.handed_off")
	assert_false(screen.policy_message.text.contains(ID))
	assert_false(screen.rows[&"privacy_policy"].disabled)
	assert_eq(save.committed_view(), before)


func test_request_and_terminal_reentry_cannot_dispatch_twice_or_rebind() -> void:
	var screen: SettingsScreen = _screen(_view())
	var previous: SERVICE = service
	var errors: Array[Error] = []
	browser.hook = func() -> void:
		assert_true(screen.rows[&"privacy_policy"].loading)
		assert_true(screen.rows[&"privacy_policy"].disabled)
		assert_false(screen.policy_toast.visible)
		errors.append(screen.bind_policy(previous))
		screen.rows[&"privacy_policy"].pressed.emit()
	var nested: Callable = func() -> void: screen.rows[&"privacy_policy"].pressed.emit()
	service.changed.connect(nested)
	screen.rows[&"privacy_policy"].pressed.emit()
	service.changed.disconnect(nested)
	browser.hook = Callable()
	assert_eq(errors, [ERR_BUSY])
	assert_eq(browser.calls.size(), 1)


func test_failure_retry_and_back_do_not_claim_sent_or_change_settings() -> void:
	var screen: SettingsScreen = _screen(_view())
	watch_signals(screen)
	browser.result = ERR_UNAVAILABLE
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_eq(screen.policy_message.text, tr("settings.policy.failed"))
	assert_eq(screen.policy_toast.kind, &"error")
	assert_false(screen.rows[&"privacy_policy"].loading)
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "back_requested", 1)
	browser.result = OK
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_eq(browser.calls.size(), 2)
	assert_eq(screen.policy_message.text, tr("settings.policy.handed_off"))


func test_hidden_and_detached_handoff_toast_deduplication() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	await _settle()
	for detached: bool in [false, true]:
		if detached:
			view.remove_child(screen)
		else:
			screen.hide()
		assert_eq(service.request_policy(), OK)
		if detached:
			view.add_child(screen)
		else:
			screen.show()
		await _settle()
		assert_true(screen.policy_toast.visible)
		screen.policy_toast.hide_message()
		screen.hide()
		screen.show()
		await _settle()
		assert_false(screen.policy_toast.visible)
	TranslationServer.set_locale("en")
	await _settle()
	assert_eq(screen.policy_message.text, tr("settings.policy.handed_off"))
	assert_false(screen.policy_toast.visible)


func test_detached_owner_exit_and_port_loss_fail_closed_until_rebind() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	view.remove_child(screen)
	remove_child(service)
	view.add_child(screen)
	await _settle()
	assert_eq(screen.policy_message.text, tr("settings.policy.unavailable"))
	assert_true(screen.rows[&"privacy_policy"].disabled)
	assert_eq(service.changed.get_connections().size(), 0)
	assert_eq(screen.bind_policy(service), ERR_UNCONFIGURED)
	watch_signals(screen)
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_signal_not_emitted(screen, "action_requested")
	_new_service()
	assert_eq(screen.bind_policy(service), OK)
	browser.free()
	TranslationServer.set_locale("en")
	await _settle()
	assert_true(screen.rows[&"privacy_policy"].disabled)
	assert_eq(screen.policy_message.text, tr("settings.policy.unavailable"))
	_new_service()
	assert_eq(screen.bind_policy(service), OK)
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_eq(browser.calls.size(), 1)


func test_keyboard_and_live_copy_do_not_replay_or_dispatch() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	await _settle()
	screen.rows[&"privacy_policy"].grab_focus()
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = down
		view.push_input(event)
	assert_eq(browser.calls.size(), 1)
	screen.policy_toast.hide_message()
	TranslationServer.set_locale("en")
	screen.theme = load("res://ui/theme/generated/theme_hc_130.tres")
	await _settle()
	assert_eq(screen.policy_message.text, tr("settings.policy.handed_off"))
	assert_false(screen.policy_toast.visible)
	assert_eq(browser.calls.size(), 1)


func _capture(view: SubViewport, name_value: String) -> void:
	var directory: String = OS.get_environment("WOW_SETTINGS_POLICY_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	assert_false(image.is_empty())
	assert_eq(image.save_png(directory.path_join(name_value + ".png")), OK)


func test_native_twelve_case_policy_feedback() -> void:
	for option: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + option, GalleryShell.OPTIONS[option])
	TranslationServer.reload_pseudolocalization()
	var sizes: Dictionary[String, Vector2i] = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}
	for layout: String in sizes:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				assert_eq(service.configure(save, browser.open), OK)
				var view: SubViewport = _view(sizes[layout])
				var screen: SettingsScreen = _screen(view)
				screen.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				await _settle()
				var name_value: String = (
					"%s_%s_%s"
					% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
				)
				for state: String in ["ready", "handed_off", "failed"]:
					if state != "ready":
						browser.result = OK if state == "handed_off" else ERR_UNAVAILABLE
						screen.rows[&"privacy_policy"].pressed.emit()
					await _settle()
					screen.scroll.ensure_control_visible(
						(
							screen.rows[&"privacy_policy"]
							if state == "ready"
							else screen.policy_message
						)
					)
					await _settle()
					assert_true(screen.top_bar.fits)
					assert_eq(screen.scroll.scroll_horizontal, 0)
					assert_lte(screen.rows[&"privacy_policy"].size.x, screen.scroll.size.x)
					assert_gte(
						screen.rows[&"privacy_policy"].size.y, float(Tokens.Touch.MIN_TARGET)
					)
					assert_lte(screen.policy_message.size.x, screen.scroll.size.x)
					await _capture(view, name_value + "_" + state)
				_views.erase(view)
				view.free()


func test_freed_save_on_retained_entry_terminates_loss_and_keeps_back_usable() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	watch_signals(screen)
	view.remove_child(screen)
	save.free()
	view.add_child(screen)
	await _settle()
	assert_eq(screen.policy_message.text, tr("settings.policy.unavailable"))
	assert_true(screen.rows[&"privacy_policy"].disabled)
	assert_false(screen.rows[&"privacy_policy"].loading)
	screen.rows[&"privacy_policy"].pressed.emit()
	assert_eq(browser.calls.size(), 0)
	assert_signal_not_emitted(screen, "action_requested")
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "back_requested", 1)


func test_freed_save_before_first_mount_fails_closed() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(save), OK)
	assert_eq(screen.bind_policy(service), OK)
	save.free()
	view.add_child(screen)
	await _settle()
	watch_signals(screen)
	assert_true(screen.rows[&"privacy_policy"].disabled)
	assert_eq(screen.policy_message.text, tr("settings.policy.unavailable"))
	TranslationServer.set_locale("en")
	await _settle()
	assert_eq(screen.policy_message.text, tr("settings.policy.unavailable"))
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "back_requested", 1)
