extends GutTest

const MEMORY: Script = preload("res://tests/integration/test_level_hud.gd")
const FIXTURE: Script = preload("res://tests/integration/test_iap_settlement.gd")
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")
const SERVICE: Script = preload("res://services/monetization.gd")
const SCENE: PackedScene = preload("res://features/settings/settings_screen.tscn")
const PATH: String = "user://t0345-settings-privacy.json"
const REMOVE: String = "nc.remove_forced_ads.v1"
var save: SAVE
var economy: ECONOMY
var config: CONFIG
var events: EVENTS
var service: SERVICE
var consent: ConsentFake
var store: FIXTURE.InspectStore
var storage: FIXTURE.InterruptedStorage
var _nodes: Array[Node] = []
var _views: Array[SubViewport] = []
var _locale: String
var _pseudo: bool
var _motion: bool


func before_each() -> void:
	_clean()
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true
	save = SAVE.new()
	economy = ECONOMY.new()
	config = CONFIG.new()
	events = EVENTS.new()
	_nodes = [save, economy, config, events]
	for node: Node in _nodes:
		add_child(node)
	var clock: Clock = FIXTURE.FixedClock.new()
	save.initialize(clock)
	economy.initialize(clock)
	storage = FIXTURE.InterruptedStorage.new(PATH)
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	economy.configure(save, config, events)
	_new_service()


func _new_service() -> void:
	service = SERVICE.new()
	_nodes.append(service)
	add_child(service)
	service.initialize(FIXTURE.FixedClock.new())
	consent = ConsentFake.new()
	assert_eq(service.configure(save, config, events, consent, AdsFake.new(), false), OK)
	store = FIXTURE.InspectStore.new()
	store.save = save
	assert_eq(store.set_products([{"id": REMOVE, "restorable": true}]), OK)
	assert_eq(service.configure_iap(economy, store), OK)


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
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


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
		assert_eq(screen.bind_privacy(service), OK)
	view.add_child(screen)
	return screen


func _settle() -> void:
	for frame: int in range(5):
		await get_tree().process_frame


func _required() -> void:
	assert_eq(
		consent.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.REQUIRED), OK
	)


func test_binding_and_unbound_flag_preserve_intent_while_bound_evidence_owns_visibility() -> void:
	var screen: SettingsScreen = _screen(_view(), false)
	watch_signals(screen)
	assert_false(screen.rows[&"privacy_options"].visible)
	screen.set_privacy_options_available(true)
	screen.rows[&"privacy_options"].pressed.emit()
	assert_signal_emitted_with_parameters(screen, "action_requested", [&"privacy_options"])
	assert_eq(consent.calls.entries.size(), 0)
	assert_eq(screen.bind_privacy(null), ERR_UNCONFIGURED)
	assert_eq(screen.bind_privacy(save), ERR_UNCONFIGURED)
	var foreign: SAVE = SAVE.new()
	foreign.initialize(FIXTURE.FixedClock.new())
	foreign.configure(MEMORY.MemoryStorage.new())
	assert_eq(foreign.load(), OK)
	var other: SettingsScreen = SCENE.instantiate()
	assert_eq(other.configure(foreign), OK)
	assert_eq(other.bind_privacy(service), ERR_UNCONFIGURED)
	other.free()
	foreign.free()
	assert_eq(screen.bind_privacy(service), OK)
	assert_false(screen.rows[&"privacy_options"].visible)
	screen.set_privacy_options_available(true)
	assert_false(screen.rows[&"privacy_options"].visible)
	_required()
	assert_true(screen.rows[&"privacy_options"].visible)
	consent.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.NOT_REQUIRED)
	assert_false(screen.rows[&"privacy_options"].visible)


func test_requested_is_once_only_loading_no_success_and_back_keeps_service_work() -> void:
	_required()
	var screen: SettingsScreen = _screen(_view())
	watch_signals(screen)
	var before: Dictionary = save.committed_view().sections.settings
	screen.rows[&"privacy_options"].pressed.emit()
	screen.rows[&"privacy_options"].pressed.emit()
	assert_eq(consent.calls.entries.size(), 1)
	assert_true(screen.rows[&"privacy_options"].loading)
	assert_true(screen.rows[&"privacy_options"].disabled)
	assert_eq(screen.privacy_message.text, tr("settings.privacy.requested"))
	assert_false(screen.privacy_toast.visible)
	assert_signal_not_emitted(screen, "action_requested")
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "back_requested", 1)
	assert_eq(service.privacy_snapshot().state, &"requested")
	assert_eq(save.committed_view().sections.settings, before)
	consent.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.NOT_REQUIRED)
	assert_false(screen.rows[&"privacy_options"].visible)
	assert_true(screen.privacy_message.visible)
	assert_eq(service.privacy_snapshot().state, &"requested")


func test_authoritative_completion_failure_and_timeout_show_feedback_and_explicit_retry() -> void:
	_required()
	var screen: SettingsScreen = _screen(_view())
	for result: Error in [OK, FAILED]:
		screen.rows[&"privacy_options"].pressed.emit()
		consent.consent_resolved.emit(ConsentAdapter.State.OBTAINED)
		assert_eq(screen.privacy_message.text, tr("settings.privacy.requested"))
		consent.privacy_options_completed.emit(result)
		var key: String = (
			"settings.privacy.completed" if result == OK else "settings.privacy.failed"
		)
		assert_eq(screen.privacy_message.text, tr(key))
		assert_eq(screen.privacy_toast.text_key, key)
		assert_false(screen.rows[&"privacy_options"].disabled)
		assert_false(screen.rows[&"privacy_options"].loading)
	screen.rows[&"privacy_options"].pressed.emit()
	assert_false(screen.privacy_toast.visible)
	service.expire_privacy_options()
	assert_eq(screen.privacy_message.text, tr("settings.privacy.unknown"))
	assert_eq(screen.privacy_toast.kind, &"error")
	screen.rows[&"privacy_options"].pressed.emit()
	assert_eq(consent.calls.entries.size(), 4)
	assert_true(screen.rows[&"privacy_options"].loading)


func test_busy_is_retryable_and_new_detached_result_supersedes_stale_command_error() -> void:
	_required()
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	assert_eq(service.start_session(), OK)
	screen.rows[&"privacy_options"].pressed.emit()
	assert_eq(screen.privacy_message.text, tr("settings.privacy.busy"))
	assert_eq(screen.privacy_toast.kind, &"error")
	view.remove_child(screen)
	service.expire_operation()
	assert_eq(service.request_privacy_options(), OK)
	consent.privacy_options_completed.emit(OK)
	view.add_child(screen)
	await _settle()
	assert_eq(screen.privacy_message.text, tr("settings.privacy.completed"))
	assert_eq(screen.privacy_toast.kind, &"success")


func test_hidden_and_detached_completion_is_shown_once_then_translation_does_not_replay() -> void:
	_required()
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	await _settle()
	for detach: bool in [false, true]:
		screen.rows[&"privacy_options"].pressed.emit()
		if detach:
			view.remove_child(screen)
		else:
			screen.hide()
		consent.privacy_options_completed.emit(OK)
		if detach:
			view.add_child(screen)
		else:
			screen.show()
		await _settle()
		assert_true(screen.privacy_toast.visible)
		screen.privacy_toast.hide_message()
		screen.hide()
		screen.show()
		await _settle()
		assert_false(screen.privacy_toast.visible)
	TranslationServer.set_locale("en")
	await _settle()
	assert_eq(screen.privacy_message.text, tr("settings.privacy.completed"))
	assert_false(screen.privacy_toast.visible)


func test_detached_owner_exit_fails_closed_and_requires_explicit_valid_rebind() -> void:
	_required()
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	view.remove_child(screen)
	remove_child(service)
	view.add_child(screen)
	await _settle()
	assert_false(screen.rows[&"privacy_options"].visible)
	assert_eq(screen.privacy_message.text, tr("settings.privacy.unavailable"))
	assert_false(screen.rows[&"privacy_options"].loading)
	assert_eq(service.privacy_changed.get_connections().size(), 0)
	assert_eq(screen.bind_privacy(service), ERR_UNCONFIGURED)
	watch_signals(screen)
	screen.set_privacy_options_available(true)
	screen.rows[&"privacy_options"].pressed.emit()
	assert_signal_not_emitted(screen, "action_requested")
	_new_service()
	_required()
	assert_eq(screen.bind_privacy(service), OK)
	screen.rows[&"privacy_options"].pressed.emit()
	assert_eq(consent.calls.entries.size(), 1)


func test_pending_replacement_and_nested_dispatch_are_rejected() -> void:
	_required()
	var screen: SettingsScreen = _screen(_view())
	var previous: SERVICE = service
	var errors: Array[Error] = []
	var nested: Callable = func() -> void:
		errors.append(screen.bind_privacy(previous))
		screen.rows[&"privacy_options"].pressed.emit()
	service.privacy_changed.connect(nested)
	screen.rows[&"privacy_options"].pressed.emit()
	service.privacy_changed.disconnect(nested)
	assert_eq(errors, [ERR_BUSY])
	assert_eq(consent.calls.entries.size(), 1)
	_new_service()
	assert_eq(screen.bind_privacy(service), ERR_BUSY)
	previous.expire_privacy_options()
	assert_eq(screen.bind_privacy(service), OK)


func test_keyboard_and_live_theme_copy() -> void:
	_required()
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	await _settle()
	screen.rows[&"privacy_options"].grab_focus()
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = down
		view.push_input(event)
	assert_eq(consent.calls.entries.size(), 1)
	TranslationServer.set_locale("en")
	screen.theme = load("res://ui/theme/generated/theme_hc_130.tres")
	await _settle()
	assert_eq(screen.privacy_message.text, tr("settings.privacy.requested"))


func _capture(view: SubViewport, name_value: String) -> void:
	var directory: String = OS.get_environment("WOW_SETTINGS_PRIVACY_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	assert_false(image.is_empty())
	assert_eq(image.save_png(directory.path_join(name_value + ".png")), OK)


func test_native_twelve_case_privacy_feedback() -> void:
	for option: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + option, GalleryShell.OPTIONS[option])
	TranslationServer.reload_pseudolocalization()
	_required()
	var sizes: Dictionary[String, Vector2i] = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}
	for layout: String in sizes:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
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
				for state: String in ["pending", "completed", "unknown"]:
					if state == "pending":
						screen.rows[&"privacy_options"].pressed.emit()
					elif state == "completed":
						consent.privacy_options_completed.emit(OK)
					else:
						screen.rows[&"privacy_options"].pressed.emit()
						service.expire_privacy_options()
					await _settle()
					screen.scroll.ensure_control_visible(screen.privacy_message)
					await _settle()
					assert_true(screen.top_bar.fits)
					assert_lte(screen.privacy_message.size.x, screen.scroll.size.x)
					assert_eq(screen.scroll.scroll_horizontal, 0)
					assert_gte(
						screen.rows[&"privacy_options"].size.y, float(Tokens.Touch.MIN_TARGET)
					)
					await _capture(view, name_value + "_" + state)
				_views.erase(view)
				view.free()
