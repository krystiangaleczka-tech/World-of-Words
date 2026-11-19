extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const NAV: Script = preload("res://services/nav.gd")
const EVENTS: Script = preload("res://services/events.gd")
const FIXTURE: Script = preload("res://tests/integration/test_shipped_campaign_flow.gd")

var _nav: NAV
var _save: SAVE
var _config: CONFIG
var _content: CONTENT
var _progress: PROGRESS
var _storage: FIXTURE.MemoryStorage
var _host: Control
var _old_motion: bool
var _old_locale: String


func before_each() -> void:
	_old_motion = Tokens.reduced_motion
	_old_locale = TranslationServer.get_locale()
	Tokens.reduced_motion = true
	_storage = FIXTURE.MemoryStorage.new()
	_nav = NAV.new()
	_save = SAVE.new()
	_content = CONTENT.new()
	_config = CONFIG.new()
	_progress = PROGRESS.new()
	var economy: ECONOMY = ECONOMY.new()
	var events: EVENTS = EVENTS.new()
	var clock: Clock = FIXTURE.FixedClock.new()
	for service: ServiceStub in [_save, _config, _content, _progress, economy, events, _nav]:
		add_child_autofree(service)
		service.initialize(clock)
	_host = Control.new()
	add_child_autofree(_host)
	_save.configure(_storage)
	_nav.configure(_save, _config, _content)
	assert_eq(_nav.configure_p2(Callable(), false), OK)
	_nav.configure_offline_campaign(
		OfflineCampaign.new(_save, _config, _content, _progress, economy, events)
	)


func after_each() -> void:
	_host.queue_free()
	await get_tree().process_frame
	TranslationServer.set_locale(_old_locale)
	Tokens.reduced_motion = _old_motion
	OS.low_processor_usage_mode = false


func _solve(level: LevelScreen) -> void:
	var board: BoardState = level.controller.get_board()
	var data: LevelData = board.get_level()
	for index: int in data.word_count():
		var word: String = data.word(index)
		if word in board.found_words():
			continue
		_attempt(level, word)


func _attempt(level: LevelScreen, word: String) -> void:
	var data: LevelData = level.controller.get_board().get_level()
	var tiles: PackedInt32Array = []
	for letter: String in word:
		for tile: int in data.tile_count():
			if data.tile_letter(tile) == letter and not tiles.has(tile):
				tiles.append(tile)
				break
	level.wheel.word_attempted.emit(tiles)


func test_real_navigation_grants_each_slot_once_and_connects_home() -> void:
	assert_eq(_nav.start(_host), OK)
	var reward: int = _config.get_int(&"economy.reward.level_complete")
	var home_slot: int = _config.get_int(&"unlocks.journey_slot")
	for slot: int in range(1, home_slot):
		var level: LevelScreen = _nav.mounted_screen() as LevelScreen
		assert_not_null(level.p2_hud)
		assert_eq(level.progress, _progress)
		assert_eq(_nav.level_slot(), slot)
		_solve(level)
		assert_eq(_progress.current_slot(), slot + 1)
		assert_eq(int(_storage.document.economy.coins), reward * slot)
		assert_eq(int(_storage.document.progress.by_lang.pl.stars), slot)
		if slot == 1:
			assert_eq(int(_storage.document.meta.onboarding_step), 1)
		var writes: int = _storage.writes
		_attempt(level, level.controller.get_board().get_level().word(0))
		assert_eq(_storage.writes, writes)
		await get_tree().process_frame
		assert_true(level.completion_layer.visible)
		level.continue_button.pressed.emit()
		if _nav.current_screen() == _nav.Screen.POSTCARD:
			assert_eq(_nav.go_to_level(slot + 1), OK)
	var current: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_eq(_nav.level_slot(), home_slot)
	assert_true(current.p2_hud.home.is_visible_in_tree())
	assert_true(current.p2_hud.settings.disabled)
	current.p2_hud.home.pressed.emit()
	assert_eq(_nav.current_screen(), _nav.Screen.HOME)
	assert_eq(_nav.go_to_level(1), OK)
	var replay: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_null(replay.p2_hud)
	var before: Dictionary = _storage.document.duplicate(true)
	_solve(replay)
	assert_true(replay.controller.is_complete())
	assert_eq(_storage.document, before, "diagnostic replay leaves the live wallet alone")


func test_missing_content_can_retry_without_rebinding_the_loaded_save() -> void:
	assert_eq(_nav.start(_host, "res://tests/fixtures/content-missing"), ERR_FILE_NOT_FOUND)
	assert_eq(_nav.boot_failure_stage, &"content")
	assert_eq(_nav.start(_host), OK)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_eq(level.progress, _progress)
	_solve(level)
	assert_eq(_progress.current_slot(), 2)
	assert_eq(int(_storage.document.progress.by_lang.pl.stars), 1)


func test_continue_after_last_slot_returns_to_home_with_committed_rewards() -> void:
	assert_eq(_content.load_manifest("pl"), OK)
	assert_eq(_config.load(), OK)
	var last: int = _content.slot_count()
	var location: Dictionary = _content.location_for_slot(last)
	var pieces: int = _config.get_int(&"meta.postcard.pieces")
	var state: Dictionary = SaveSchema.LANGUAGE_STATE.duplicate(true)
	state.current_slot = last
	state.highest_completed_slot = last - 1
	state.completed_slot = last - 1
	state.stars = last - 1
	state.location_stars[location.id] = last - int(location.first)
	state.location_pieces[location.id] = pieces
	_storage.document.progress.by_lang.pl = state
	assert_eq(_nav.start(_host), OK)
	assert_eq(_nav.go_to_level(last), OK)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	_solve(level)
	assert_eq(_progress.current_slot(), last + 1)
	assert_eq(_progress.stars(), last)
	await get_tree().process_frame
	assert_true(level.completion_layer.visible)
	assert_false(level.continue_button.disabled)
	var committed: Dictionary = _storage.document.duplicate(true)
	level.continue_button.pressed.emit()
	assert_eq(_nav.current_screen(), _nav.Screen.HOME)
	assert_eq(_storage.document, committed)
	assert_eq(_nav.go_to_level(last), OK)
	var replay: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_null(replay.p2_hud)
	assert_true(replay.completion_layer.visible)
	assert_true(replay.continue_button.disabled)
	assert_eq(_storage.document, committed)


func test_current_slot_connects_hint_and_bonus_to_the_saved_wallet() -> void:
	var state: Dictionary = SaveSchema.LANGUAGE_STATE.duplicate(true)
	state.current_slot = 7
	state.highest_completed_slot = 6
	state.completed_slot = 6
	_storage.document.progress.by_lang.pl = state
	_storage.document.meta.onboarding_step = 1
	_storage.document.economy.items.hint = 1
	assert_eq(_nav.start(_host), OK)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_true(level.hint_button.is_visible_in_tree())
	level.hint_button.pressed.emit()
	assert_eq(int(_storage.document.economy.items.hint), 0)
	assert_eq(level.controller.get_board().revealed_cells().size(), 1)
	await get_tree().process_frame
	_attempt(level, "KUR")
	assert_eq(int(_storage.document.economy.bonus_counter), 1)
	assert_true("KUR" in level.controller.get_board().bonus_words())
	assert_eq(int(_storage.document.economy.coins), 0, "bonus checkpoint grants no coins mid-level")


func test_existing_v3_progress_keeps_its_slot_stars_and_wallet() -> void:
	var previous: Dictionary = SaveSchemaV3.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-11T12:00:00Z", "0.1.0"
	)
	var state: Dictionary = SaveSchemaV3.LANGUAGE_STATE.duplicate(true)
	state.current_slot = 2
	state.highest_completed_slot = 1
	state.completed_slot = 1
	state.stars = 1
	previous.progress.by_lang.pl = state
	previous.economy.coins = 17
	_storage.document = previous
	_storage.fail = true
	assert_eq(_nav.start(_host), ERR_FILE_CANT_WRITE)
	assert_eq(_nav.boot_failure_stage, &"save")
	assert_eq(_nav.current_screen(), _nav.Screen.BOOT)
	assert_eq(int(_storage.document.schema_version), 3)
	_storage.fail = false
	assert_eq(_nav.start(_host), OK)
	assert_eq(_nav.level_slot(), 2)
	assert_eq(_progress.stars(), 1)
	assert_eq(int(_save.committed_view().sections.economy.coins), 17)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_null(level.tutorial_ui)
	_solve(level)
	assert_eq(_progress.current_slot(), 3)
	assert_eq(int(_storage.document.progress.by_lang.pl.stars), 2)
	assert_eq(
		int(_storage.document.economy.coins), 17 + _config.get_int(&"economy.reward.level_complete")
	)
