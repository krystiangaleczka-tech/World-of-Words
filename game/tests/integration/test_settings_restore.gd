extends GutTest

const MEMORY: Script = preload("res://tests/integration/test_level_hud.gd")
const FIXTURE: Script = preload("res://tests/integration/test_iap_settlement.gd")
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")
const SERVICE: Script = preload("res://services/monetization.gd")
const SCENE: PackedScene = preload("res://features/settings/settings_screen.tscn")
const PATH: String = "user://t0342-settings-restore.json"
const REMOVE: String = "nc.remove_forced_ads.v1"
var save: SAVE
var economy: ECONOMY
var config: CONFIG
var events: EVENTS
var service: SERVICE
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
	assert_eq(service.configure(save, config, events, ConsentFake.new(), AdsFake.new(), false), OK)
	store = FIXTURE.InspectStore.new()
	store.save = save
	assert_eq(store.set_products([{"id": REMOVE, "restorable": true}]), OK)
	store.set_outcome(&"restore", &"manual")
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
		assert_eq(screen.bind_restore(service), OK)
	view.add_child(screen)
	return screen


func _settle() -> void:
	for frame: int in range(5):
		await get_tree().process_frame


func _count(method: String) -> int:
	var result: int = 0
	for call: Dictionary in store.calls.entries:
		if call.method == method:
			result += 1
	return result


func _complete(key: String = "", blocked: bool = false) -> void:
	var batch: Array[StoreTransaction] = []
	if not key.is_empty():
		storage.stop = &"temp_opened" if blocked else &""
		var transaction: StoreTransaction = StoreTransaction.new(
			key, REMOVE, StoreTransaction.State.PURCHASED, -1, "", true
		)
		store.transaction_updated.emit(transaction)
		batch.append(transaction)
	store.restore_completed.emit(batch)


func test_binding_requires_configured_same_owner_and_unbound_preserves_intent() -> void:
	var screen: SettingsScreen = _screen(_view(), false)
	watch_signals(screen)
	screen.rows[&"restore"].pressed.emit()
	assert_signal_emit_count(screen, "action_requested", 1)
	assert_eq(_count("restore"), 0)
	assert_eq(screen.bind_restore(null), ERR_UNCONFIGURED)
	var empty: SERVICE = SERVICE.new()
	assert_eq(screen.bind_restore(empty), ERR_UNCONFIGURED)
	empty.free()
	var foreign: SAVE = SAVE.new()
	foreign.initialize(FIXTURE.FixedClock.new())
	foreign.configure(MEMORY.MemoryStorage.new())
	assert_eq(foreign.load(), OK)
	var foreign_screen: SettingsScreen = SCENE.instantiate()
	assert_eq(foreign_screen.configure(foreign), OK)
	assert_eq(foreign_screen.bind_restore(service), ERR_UNCONFIGURED)
	foreign_screen.free()
	assert_false(service.restore_owner_matches(foreign))
	foreign.free()
	assert_true(service.restore_owner_matches(save))
	assert_eq(screen.bind_restore(service), OK)
	assert_eq(screen.bind_restore(null), ERR_UNCONFIGURED)
	screen.rows[&"restore"].pressed.emit()
	assert_eq(_count("restore"), 1)
	assert_signal_emit_count(screen, "action_requested", 1)


func test_requested_loading_prevents_duplicate_and_back_does_not_cancel() -> void:
	var screen: SettingsScreen = _screen(_view())
	var settings: Dictionary = save.committed_view().sections.settings
	watch_signals(screen)
	screen.rows[&"restore"].pressed.emit()
	screen.rows[&"restore"].pressed.emit()
	assert_eq(_count("restore"), 1)
	assert_true(screen.rows[&"restore"].loading)
	assert_true(screen.rows[&"restore"].disabled)
	assert_eq(screen.restore_message.text, tr("settings.restore.requested"))
	assert_false(screen.restore_toast.visible)
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "back_requested", 1)
	assert_eq(service.restore_snapshot().state, &"requested")
	assert_eq_deep(save.committed_view().sections.settings, settings)


func test_verified_empty_and_owned_results_show_only_proved_count() -> void:
	var screen: SettingsScreen = _screen(_view())
	screen.rows[&"restore"].pressed.emit()
	_complete()
	assert_eq(screen.restore_message.text, tr("settings.restore.empty"))
	assert_eq(screen.restore_toast.text_key, "settings.restore.empty")
	assert_false(screen.rows[&"restore"].loading)
	screen.rows[&"restore"].pressed.emit()
	assert_false(screen.restore_toast.visible)
	_complete("owned")
	assert_eq(screen.restore_message.text, tr("settings.restore.completed") % "1")
	assert_eq(screen.restore_toast.text_key, "settings.restore.success")
	assert_eq(screen.restore_toast.kind, &"success")
	assert_true(save.committed_view().sections.monetization.remove_forced_ads)


func test_failure_timeout_and_explicit_retry() -> void:
	var screen: SettingsScreen = _screen(_view())
	screen.rows[&"restore"].pressed.emit()
	store.restore_failed.emit(ERR_UNAVAILABLE)
	assert_eq(screen.restore_message.text, tr("settings.restore.failed"))
	assert_false(screen.rows[&"restore"].disabled)
	assert_eq(screen.restore_toast.kind, &"error")
	screen.rows[&"restore"].pressed.emit()
	service.expire_restore()
	assert_eq(screen.restore_message.text, tr("settings.restore.unknown"))
	assert_false(screen.rows[&"restore"].loading)
	screen.rows[&"restore"].pressed.emit()
	_complete()
	assert_eq(screen.restore_message.text, tr("settings.restore.empty"))
	assert_eq(_count("restore"), 3)


func test_settlement_retry_never_requests_another_restore() -> void:
	var screen: SettingsScreen = _screen(_view())
	screen.rows[&"restore"].pressed.emit()
	_complete("blocked", true)
	assert_false(screen.rows[&"restore"].loading)
	assert_true(screen.rows[&"restore"].disabled)
	assert_true(screen.restore_retry.visible)
	assert_eq(screen.restore_message.text, tr("settings.restore.settling"))
	screen.restore_retry.pressed.emit()
	assert_eq(service.restore_snapshot().state, &"settling")
	assert_eq(screen.restore_toast.kind, &"error")
	assert_true(screen.restore_toast.visible)
	assert_eq(_count("finish"), 0)
	storage.stop = &""
	screen.restore_retry.pressed.emit()
	assert_eq(_count("restore"), 1)
	assert_eq(_count("fetch_unfinished"), 0)
	assert_eq(_count("finish"), 1)
	assert_eq(screen.restore_message.text, tr("settings.restore.completed") % "1")
	assert_false(screen.restore_retry.visible)


func test_result_while_detached_or_hidden_is_shown_once_on_return() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	screen.rows[&"restore"].pressed.emit()
	view.remove_child(screen)
	_complete()
	view.add_child(screen)
	await _settle()
	assert_true(screen.restore_toast.visible)
	screen.restore_toast.hide_message()
	view.remove_child(screen)
	view.add_child(screen)
	await _settle()
	assert_false(screen.restore_toast.visible)
	screen.rows[&"restore"].pressed.emit()
	screen.hide()
	_complete("hidden")
	assert_false(screen.restore_toast.visible)
	screen.show()
	await _settle()
	assert_true(screen.restore_toast.visible)
	assert_eq(screen.restore_toast.text_key, "settings.restore.success")
	screen.restore_toast.hide_message()
	screen.hide()
	screen.show()
	assert_false(screen.restore_toast.visible)


func test_service_loss_fails_closed_and_valid_rebind_recovers() -> void:
	var screen: SettingsScreen = _screen(_view())
	screen.rows[&"restore"].pressed.emit()
	service.free()
	assert_true(screen.rows[&"restore"].disabled)
	assert_false(screen.rows[&"restore"].loading)
	assert_eq(screen.restore_message.text, tr("settings.restore.unavailable"))
	watch_signals(screen)
	screen.rows[&"restore"].pressed.emit()
	assert_signal_not_emitted(screen, "action_requested")
	_new_service()
	assert_eq(screen.bind_restore(service), OK)
	assert_false(screen.rows[&"restore"].disabled)
	assert_false(screen.restore_message.visible)


func test_reentrant_restore_binding_and_row_dispatch_are_blocked() -> void:
	var screen: SettingsScreen = _screen(_view())
	var errors: Array[Error] = []
	service.restore_changed.connect(
		func() -> void:
			errors.append(screen.bind_restore(service))
			screen.rows[&"restore"].pressed.emit()
	)
	screen.rows[&"restore"].pressed.emit()
	assert_eq(errors, [ERR_BUSY])
	assert_eq(_count("restore"), 1)


func test_keyboard_restore_and_live_translation_preserve_proof() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	await _settle()
	screen.rows[&"restore"].grab_focus()
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = down
		view.push_input(event)
	assert_eq(_count("restore"), 1)
	_complete("translated")
	screen.restore_toast.hide_message()
	TranslationServer.set_locale("en")
	screen.theme = load("res://ui/theme/generated/theme_hc_130.tres")
	await _settle()
	assert_eq(screen.restore_message.text, tr("settings.restore.completed") % "1")
	assert_eq(service.restore_snapshot().restored_count, 1)
	assert_false(screen.restore_toast.visible)


func _capture(view: SubViewport, name_value: String) -> void:
	var directory: String = OS.get_environment("WOW_SETTINGS_RESTORE_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	assert_false(image.is_empty())
	assert_eq(image.save_png(directory.path_join(name_value + ".png")), OK)


func test_native_twelve_case_feedback_and_settlement_layout() -> void:
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
				var view: SubViewport = _view(sizes[layout])
				var screen: SettingsScreen = SCENE.instantiate()
				assert_eq(screen.configure(save), OK)
				assert_eq(screen.bind_restore(service), OK)
				screen.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				view.add_child(screen)
				await _settle()
				var name_value: String = (
					"%s_%s_%s"
					% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
				)
				screen.rows[&"restore"].pressed.emit()
				await _settle()
				screen.scroll.ensure_control_visible(screen.restore_message)
				await _settle()
				assert_true(screen.top_bar.fits)
				assert_lte(screen.restore_message.size.x, screen.scroll.size.x)
				await _capture(view, name_value + "_pending")
				_complete(name_value + "owned")
				await _settle()
				await _capture(view, name_value + "_completed")
				screen.restore_toast.hide_message()
				screen.rows[&"restore"].pressed.emit()
				_complete(name_value + "save", true)
				await _settle()
				screen.scroll.ensure_control_visible(screen.restore_retry)
				await _settle()
				assert_false(screen.rows[&"restore"].loading)
				assert_gte(screen.restore_retry.size.y, float(Tokens.Touch.MIN_TARGET))
				assert_lte(screen.restore_retry.size.x, screen.scroll.size.x)
				assert_eq(screen.scroll.scroll_horizontal, 0)
				assert_true(
					screen.scroll.get_global_rect().intersects(
						screen.restore_retry.get_global_rect()
					)
				)
				await _capture(view, name_value + "_settling")
				storage.stop = &""
				screen.restore_retry.pressed.emit()
				assert_eq(service.restore_snapshot().state, &"completed")
				_views.erase(view)
				view.free()


func test_pending_service_replacement_is_rejected_before_rebind() -> void:
	var screen: SettingsScreen = _screen(_view())
	screen.rows[&"restore"].pressed.emit()
	var previous: SERVICE = service
	_new_service()
	assert_eq(screen.bind_restore(service), ERR_BUSY)
	assert_true(screen.rows[&"restore"].loading)
	previous.expire_restore()
	assert_eq(screen.bind_restore(service), OK)
	assert_false(screen.restore_message.visible)
	assert_false(screen.rows[&"restore"].loading)
	screen.rows[&"restore"].pressed.emit()
	assert_eq(_count("restore"), 1)


func test_busy_command_never_claims_success_and_can_be_retried() -> void:
	var screen: SettingsScreen = _screen(_view())
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.purchase(REMOVE), OK)
	var token: int = store.operation_token()
	screen.rows[&"restore"].pressed.emit()
	assert_eq(_count("restore"), 0)
	assert_eq(screen.restore_message.text, tr("settings.restore.busy"))
	assert_eq(screen.restore_toast.kind, &"error")
	assert_true(store.settle(token))
	screen.rows[&"restore"].pressed.emit()
	assert_eq(_count("restore"), 1)
	assert_eq(screen.restore_message.text, tr("settings.restore.requested"))
	assert_false(screen.restore_toast.visible)


func test_detached_service_exit_invalidates_binding_until_explicit_rebind() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	screen.rows[&"restore"].pressed.emit()
	view.remove_child(screen)
	remove_child(service)
	view.add_child(screen)
	await _settle()
	assert_eq(screen.restore_message.text, tr("settings.restore.unavailable"))
	assert_false(screen.rows[&"restore"].loading)
	assert_true(screen.rows[&"restore"].disabled)
	assert_eq(service.restore_changed.get_connections().size(), 0)
	assert_eq(screen.bind_restore(service), ERR_UNCONFIGURED)
	screen.rows[&"restore"].pressed.emit()
	assert_eq(_count("restore"), 1)
	_new_service()
	assert_eq(screen.bind_restore(service), OK)
	screen.rows[&"restore"].pressed.emit()
	assert_eq(_count("restore"), 1)
	assert_true(screen.rows[&"restore"].loading)


func test_new_result_while_detached_supersedes_old_command_error() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.purchase(REMOVE), OK)
	var token: int = store.operation_token()
	screen.rows[&"restore"].pressed.emit()
	assert_eq(screen.restore_message.text, tr("settings.restore.busy"))
	view.remove_child(screen)
	assert_true(store.settle(token))
	assert_eq(service.restore_purchases(), OK)
	_complete()
	view.add_child(screen)
	await _settle()
	assert_eq(screen.restore_message.text, tr("settings.restore.empty"))
	assert_eq(screen.restore_toast.kind, &"success")
