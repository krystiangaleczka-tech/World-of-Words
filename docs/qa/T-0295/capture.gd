extends SceneTree
## Actual LevelScreen and real durable owners, isolated injected memory storage.

var count: int = 0


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var catalog: LocaleCatalog = LocaleCatalog.new()
	assert(catalog.register_all() == OK)
	Tokens.reduced_motion = true
	for key: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + key, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	for layout: String in GalleryShell.SIZES:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				await _case(layout, pseudo, hc, false)
				await _case(layout, pseudo, hc, true)
	catalog.unregister()
	print("T-0295 native screenshots: ", count)
	quit()


func _case(layout: String, pseudo: bool, hc: bool, lost: bool) -> void:
	var fixture: Script = load("res://tests/integration/test_startup_recovery.gd")
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var view: SubViewport = SubViewport.new()
	view.size = GalleryShell.SIZES[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var save: Node = load("res://services/save.gd").new()
	var config: Node = fixture.RecoveryConfig.new()
	var content: Node = load("res://services/content.gd").new()
	var monetization: Node = fixture.RestorePort.new()
	var analytics: Node = load("res://services/analytics.gd").new()
	var nav: Node = load("res://services/nav.gd").new()
	for node: Node in [save, config, content, monetization, analytics, nav]:
		view.add_child(node)
		node.initialize(Clock.new())
	var storage: RefCounted = fixture.RecoveryStorage.new()
	if lost:
		storage.mode = &"lost"
	save.configure(storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	nav.configure(save, config, content)
	assert(nav.configure_p2(func() -> Error: return OK, false) == OK)
	var recovery: RefCounted = load("res://services/nav/startup_recovery.gd").new()
	recovery.configure(nav, save, config, content, monetization, analytics)
	var theme: Theme = load("res://ui/theme/generated/theme_hc_130.tres" if hc else "res://ui/theme/generated/theme_default_100.tres")
	var prefix: String = "%s_%s_%s" % [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
	if not lost:
		assert(recovery.start(view, "res://tests/fixtures/t0295-missing") != OK)
		await _shot(view, recovery, theme, prefix, "content_error")
		recovery.presentation().get_node("Secondary").pressed.emit()
		assert(nav.current_screen() == nav.Screen.HOME)
		(nav.mounted_screen() as Control).theme = theme
		await _shot(view, recovery, theme, prefix, "home_error")
	else:
		assert(recovery.start(view, "res://tests/fixtures/content") == OK)
		await _shot(view, recovery, theme, prefix, "lost_save")
		recovery.presentation().get_node("State").action_requested.emit()
		await _shot(view, recovery, theme, prefix, "restore_unavailable")
		monetization.result = OK
		recovery.presentation().get_node("State").action_requested.emit()
		await _shot(view, recovery, theme, prefix, "restore_requested")
	recovery.close()
	nav.configure(null, null, null)
	nav.free()
	await process_frame
	view.free()
	await process_frame


func _shot(view: SubViewport, recovery: RefCounted, theme: Theme, prefix: String, state: String) -> void:
	var top: Control = recovery.presentation()
	while top.get_parent() is Control:
		top = top.get_parent()
	top.theme = theme
	for frame: int in range(4):
		await process_frame
	RenderingServer.force_draw(false)
	assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/qa/T-0295/recovery_%s_%s.png" % [prefix, state])) == OK)
	count += 1
