extends SceneTree
## Native-rendered QA fixtures only; no production saves, locations or illustration assets.


func _initialize() -> void:
	_capture.call_deferred()


func _art() -> Texture2D:
	var image: Image = Image.create(800, 500, false, Image.FORMAT_RGBA8)
	image.fill(Tokens.Palette.SURFACE_ALT)
	image.fill_rect(Rect2i(0, 330, 800, 170), Tokens.Palette.SURFACE)
	image.fill_rect(Rect2i(80, 210, 150, 120), Tokens.Palette.SURFACE)
	image.fill_rect(Rect2i(270, 200, 220, 130), Tokens.Palette.PRIMARY)
	image.fill_rect(Rect2i(540, 230, 180, 100), Tokens.Palette.SURFACE)
	return ImageTexture.create_from_image(image)


func _capture() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = arguments[0]
	DirAccess.make_dir_recursive_absolute(directory)
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for with_art: bool in [true, false]:
				await _one(directory, dimensions, pseudo, with_art)
	quit()


func _one(directory: String, dimensions: Vector2i, pseudo: bool, with_art: bool) -> void:
	# Load after autoload registration; the external SceneTree parses before it.
	var fixtures: Script = load("res://tests/integration/test_home_screen.gd")
	var save: Node = load("res://services/save.gd").new()
	var config: Node = fixtures.FixtureConfig.new()
	var content: Node = fixtures.FixtureContent.new()
	var nav: Node = fixtures.NavigationIntent.new()
	var storage: SaveStorage = fixtures.MemoryStorage.new()
	storage.document.economy.coins = 240
	storage.document.progress.by_lang.pl.current_slot = 2
	storage.document.progress.by_lang.pl.highest_completed_slot = 1
	storage.document.progress.by_lang.pl.completed_slot = 1
	storage.document.progress.by_lang.pl.location_pieces = {"fixture": 2}
	storage.document.settings.high_contrast = pseudo
	storage.document.settings.text_scale = 2 if pseudo else 0
	for service: Node in [save, config, content, nav]:
		root.add_child(service)
	for service: ServiceStub in [save, config, content]:
		service.initialize(fixtures.FixedClock.new())
	save.configure(storage)
	assert(save.load() == OK)
	assert(config.load() == OK)
	assert(content.load_manifest("pl", "res://tests/fixtures/content") == OK)
	var translation: Translation = Translation.new()
	translation.set_locale("pl")
	translation.add_message(&"journey.location.fixture", "Miejsce testowe")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var viewport: SubViewport = SubViewport.new()
	viewport.size = dimensions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: Control = load("res://features/home/home.tscn").instantiate() as Control
	screen.debug_insets = Rect2(Vector2(24, 48), Vector2(24, 48))
	screen.configure(
		save,
		content,
		config,
		nav,
		func(_path: String) -> Texture2D: return _art() if with_art else null
	)
	viewport.add_child(screen)
	for _frame: int in 4:
		await process_frame
	RenderingServer.force_draw(false)
	var name: String = (
		"%s_%s_%s.png"
		% [
			screen.layout_class,
			"PSEUDO_hc130" if pseudo else "PL_default100",
			"fixture" if with_art else "missing_art"
		]
	)
	assert(viewport.get_texture().get_image().save_png(directory.path_join(name)) == OK)
	viewport.free()
	TranslationServer.remove_translation(translation)
	for service: Node in [save, config, content, nav]:
		service.free()
	await process_frame
