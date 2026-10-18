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
	print("T-0294 native screenshots: ", count)
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
	for node: Node in [save, config, economy, events, content, platform, nav]:
		view.add_child(node)
	save.initialize(Clock.new())
	save.configure(Storage.new())
	assert(save.load() == OK)
	assert(config.load() == OK)
	assert(content.load_manifest("pl") == OK)
	economy.initialize(Clock.new())
	economy.configure(save, config, events)
	nav.configure(save, config, content)
	var port: RefCounted = load("res://services/debug/tools.gd").new()
	port.configure(save, economy, config, platform)
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
	for bottom: bool in [false, true]:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value) if bottom else 0
		for frame: int in range(4):
			await process_frame
		RenderingServer.force_draw(false)
		assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/qa/T-0294/debug_%s_%s.png" % [prefix, "bottom" if bottom else "top"])) == OK)
		count += 1
	view.free()
