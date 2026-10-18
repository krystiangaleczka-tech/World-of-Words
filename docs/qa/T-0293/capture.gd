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
var metadata: Dictionary = {}


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	for key: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + key, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	for layout: String in ["COMPACT", "REGULAR", "TABLET"]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				await _case(layout, pseudo, hc)
	print("T-0293 native screenshots: ", count)
	var output: FileAccess = FileAccess.open("res://../docs/qa/T-0293/summaries.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(metadata,"\t",true)+"\n")
	quit()


func _case(layout: String, pseudo: bool, hc: bool) -> void:
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	Tokens.reduced_motion = false
	var view: SubViewport = SubViewport.new()
	view.size = {"COMPACT": Vector2i(1080, 1920), "REGULAR": Vector2i(1080, 2340), "TABLET": Vector2i(1440, 1920)}[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var save: Node = load("res://services/save.gd").new()
	var config: Node = load("res://services/config.gd").new()
	var economy: Node = load("res://services/economy.gd").new()
	var events: Node = load("res://services/events.gd").new()
	var content: Node = load("res://services/content.gd").new()
	for node: Node in [save, config, economy, events, content]:
		view.add_child(node)
	save.initialize(Clock.new())
	save.configure(Storage.new())
	assert(save.load() == OK)
	assert(config.load() == OK)
	assert(content.load_manifest("pl") == OK)
	economy.initialize(Clock.new())
	economy.configure(save, config, events)
	var page: Control = (load("res://features/level/level.tscn") as PackedScene).instantiate()
	page.configure(save, content, 1, events)
	assert(page.configure_p2(economy, config) == OK)
	assert(page.configure_tutorial() == OK)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 291
	page.configure_rng(rng)
	page.theme = load("res://ui/theme/generated/theme_hc_130.tres" if hc else "res://ui/theme/generated/theme_default_100.tres")
	view.add_child(page)
	await _settle()
	var prefix: String = "%s_%s_%s" % [layout,"PSEUDO" if pseudo else "PL","hc130" if hc else "default100"]
	metadata[prefix] = {"name":page.accessibility_name,"description":page.accessibility_description}
	await _shot(view,page,prefix,"summary")
	view.free()


func _shot(view: SubViewport, page: Control, prefix: String, state: String) -> void:
	await _settle()
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(view.size))
	for control: Control in [page.wheel, page.board_view, page.preview, page.tutorial_ui.caption]:
		assert(bounds.encloses(control.get_global_rect()))
	assert(page.tutorial_ui.hand.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(not page.hint_button.is_visible_in_tree() and not page.shuffle_button.is_visible_in_tree())
	RenderingServer.force_draw(false)
	assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/qa/T-0293/a11y_%s_%s.png" % [prefix, state])) == OK)
	count += 1


func _settle() -> void:
	for frame: int in range(4):
		await process_frame
