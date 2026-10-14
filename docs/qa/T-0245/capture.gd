extends SceneTree
## Native UI evidence using test-only metadata and explicitly non-production gradient artwork.

const PATH: String = "user://t0245-capture.json"
var _save: Node
var _content: Node
var _config: Node


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	Tokens.reduced_motion = true
	for key: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + key, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	_save = load("res://services/save.gd").new()
	_content = load("res://tests/fixtures/journey/catalog.gd").new()
	_config = load("res://services/config.gd").new()
	for service: ServiceStub in [_save, _content, _config]:
		service.initialize(Clock.new())
		root.add_child(service)
	_save.configure(
		SaveStorage.new(PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert(_save.load() == OK)
	assert(_content.load_manifest("pl", "res://tests/fixtures/content") == OK)
	assert(_config.load() == OK)
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.current_slot = 2
	progress.by_lang.pl.highest_completed_slot = 1
	progress.by_lang.pl.completed_slot = 1
	progress.by_lang.pl.stars = 7
	progress.by_lang.pl.location_pieces = {"harbor": 1, "market": 2, "hill": 0}
	assert(_save.set_section(&"progress", progress) == OK)
	assert(_save.flush() == OK)
	for layout: String in ["COMPACT", "REGULAR", "TABLET"]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				await _shot(layout, pseudo, hc, true, "states")
	await _shot("REGULAR", false, false, false, "missing_art")
	progress.by_lang.pl.current_slot = 4
	progress.by_lang.pl.highest_completed_slot = 3
	progress.by_lang.pl.completed_slot = 3
	assert(_save.set_section(&"progress", progress) == OK)
	assert(_save.flush() == OK)
	await _shot("REGULAR", false, false, true, "region_complete")
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	quit()


func _shot(layout: String, pseudo: bool, hc: bool, art: bool, state: String) -> void:
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var viewport: SubViewport = SubViewport.new()
	viewport.size = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}[layout]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: ScreenScaffold = load("res://features/journey/journey.gd").new()
	screen.theme = load(
		(
			"res://ui/theme/generated/theme_%s_%d.tres"
			% ["hc" if hc else "default", 130 if hc else 100]
		)
	)
	screen.debug_insets = Rect2(Vector2(24, 48), Vector2(24, 48))
	var resolver: Callable = func(_location: Dictionary) -> Texture2D:
		if not art:
			return null
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.width = 600
		texture.height = 400
		texture.gradient = Gradient.new()
		texture.gradient.colors = PackedColorArray([Tokens.Palette.PRIMARY, Tokens.Palette.BONUS])
		return texture
	screen.configure(_save, _content, _config, root.get_node("Nav"), resolver)
	viewport.add_child(screen)
	for frame: int in 8:
		await process_frame
	for position: String in ["top", "bottom"]:
		if position == "bottom":
			var scroll: ScrollContainer = screen.find_child("Locations", true, false)
			scroll.ensure_control_visible(screen.find_child("Location_hill", true, false))
			for frame: int in 3:
				await process_frame
		RenderingServer.force_draw(false)
		var path: String = (
			"/workspace/World-of-Words/docs/qa/T-0245/journey_%s_%s_%s_%s_%s.png"
			% [
				layout,
				"PSEUDO" if pseudo else "PL",
				"hc130" if hc else "default100",
				state,
				position
			]
		)
		assert(viewport.get_texture().get_image().save_png(path) == OK)
		print("CAPTURE ", path)
	viewport.queue_free()
	await process_frame
