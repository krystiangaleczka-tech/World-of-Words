extends SceneTree
## Actual LevelScreen and real durable owners, isolated injected memory storage.

class Storage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK

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
				await _case(layout, pseudo, hc)
	catalog.unregister()
	print("T-0329 native screenshots: ", count)
	quit()


func _case(layout: String, pseudo: bool, hc: bool) -> void:
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var view: SubViewport = SubViewport.new()
	view.size = GalleryShell.SIZES[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var save: Node = load("res://services/save.gd").new()
	var config: Node = load("res://services/config.gd").new()
	var economy: Node = load("res://services/economy.gd").new()
	var events: Node = load("res://services/events.gd").new()
	var content: Node = load("res://services/content.gd").new()
	var platform: Node = load("res://platform/platform.gd").new()
	var nav: Node = load("res://services/nav.gd").new()
	var analytics: Node = load("res://services/analytics.gd").new()
	var clock: Clock = load("res://services/debug/clock.gd").new(Clock.new())
	for node: Node in [save, config, economy, events, content, platform, nav, analytics]:
		view.add_child(node)
		node.initialize(clock)
	save.configure(Storage.new())
	assert(save.load() == OK)
	assert(config.load() == OK)
	assert(content.load_manifest("pl") == OK)
	economy.configure(save, config, events)
	nav.configure(save, config, content)
	var port: RefCounted = load("res://services/debug/tools.gd").new()
	port.configure(save, economy, config, platform)
	assert(analytics.load() == OK)
	assert(analytics.configure_stub(100) == OK)
	var monitor: RefCounted = load("res://services/debug/diagnostics.gd").new()
	assert(monitor.configure(clock, save, economy, config, analytics, events) == OK)
	port.diagnostics = monitor
	assert(analytics.track(&"settings_changed", {"setting": "music_volume"}) == OK)
	var page: Control = load("res://features/debug/debug.tscn").instantiate()
	page.configure(save, content, nav)
	page.configure_p2_tools(port)
	page.theme = load("res://ui/theme/generated/theme_hc_130.tres" if hc else "res://ui/theme/generated/theme_default_100.tres")
	view.add_child(page)
	for frame: int in range(4):
		await process_frame
	var scroll: ScrollContainer = page.find_child("DebugScroll", true, false)
	assert(scroll != null)
	var prefix: String = "%s_%s_%s" % [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
	var panel: Control = page.find_child("Diagnostics", true, false)
	for state: String in ["top", "clock", "bottom"]:
		scroll.scroll_vertical = 0 if state == "top" else (int(panel.position.y + panel.get_parent().position.y) if state == "clock" else int(scroll.get_v_scroll_bar().max_value))
		for frame: int in range(4):
			await process_frame
		RenderingServer.force_draw(false)
		assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/qa/T-0329/debug_%s_%s.png" % [prefix, state])) == OK)
		count += 1
	monitor.close()
	view.free()
