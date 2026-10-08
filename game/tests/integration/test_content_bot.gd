extends GutTest
## Bot completes every shippable level without hints (FR-CONT-07).

const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const FIXTURE_ROOT: String = "res://tests/fixtures/content"
const SHIPPED_ROOT: String = "res://content"


func test_fixture_levels_are_formable() -> void:
	var checked: int = _check_root(FIXTURE_ROOT)
	assert_gt(checked, 0, "fixture content must hold levels")


func test_shipped_levels_are_formable() -> void:
	var checked: int = _check_root(SHIPPED_ROOT)
	if checked == 0:
		pass_test("no shipped content yet (first packs arrive with T-0127)")


func test_bot_rejects_unformable_word() -> void:
	var level: LevelData = (
		LevelData
		. from_dict(
			{
				"id": "pl-c-000001",
				"slot": 1,
				"letters": ["K", "O", "T"],
				"words": [{"w": "KOT", "x": 0, "y": 0, "dir": "h"}],
				"bonus": [],
				"grid": {"w": 3, "h": 1},
			}
		)
	)
	assert_eq(level.spell(_pick_tiles(level, "TOK")), "TOK")
	assert_eq(_pick_tiles(level, "KOTT").size(), 0)
	assert_eq(_pick_tiles(level, "KAT").size(), 0)


func test_bot_completes_crossings_and_repeated_letters() -> void:
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	add_child_autofree(content)
	assert_eq(content.load_manifest("pl", FIXTURE_ROOT), OK)
	var level: LevelData = content.level_for_slot(3)
	var tiles: PackedInt32Array = _pick_tiles(level, "LASKA")
	assert_eq(tiles, PackedInt32Array([0, 1, 2, 3, 4]))
	var board: BoardState = _play_level(level)
	assert_eq(board.found_words().size(), 2)
	assert_eq(board.revealed_cells().size(), 8, "crossing cell counts once")


func test_formable_unknown_word_cannot_complete_board() -> void:
	var level: LevelData = (
		LevelData
		. from_dict(
			{
				"id": "pl-c-000001",
				"slot": 1,
				"letters": ["K", "O", "T"],
				"words": [{"w": "KOT", "x": 0, "y": 0, "dir": "h"}],
				"bonus": [],
				"grid": {"w": 3, "h": 1},
			}
		)
	)
	var board: BoardState = BoardState.new(level)
	watch_signals(board)
	var snapshot: Dictionary = board.to_dict()
	var result: AttemptResult = board.evaluate(_pick_tiles(level, "TOK"))
	assert_eq(result.word, "TOK")
	assert_eq(result.kind, AttemptResult.Kind.INVALID)
	assert_false(board.is_complete())
	assert_eq_deep(board.to_dict(), snapshot)
	assert_signal_not_emitted(board, "completed")


# Checks every language under root; returns the number of levels checked.
func _check_root(root: String) -> int:
	var directory: DirAccess = DirAccess.open(root)
	if directory == null:
		return 0
	var checked: int = 0
	for language: String in directory.get_directories():
		if not FileAccess.file_exists(root.path_join(language).path_join("manifest.json")):
			continue
		var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
		add_child_autofree(content)
		watch_signals(content)
		assert_eq(content.load_manifest(language, root), OK, root + "/" + language)
		for slot: int in range(1, content.slot_count() + 1):
			var level: LevelData = content.level_for_slot(slot)
			assert_not_null(level, "%s/%s slot %d" % [root, language, slot])
			if level != null:
				assert_eq(level.get_slot(), slot)
				_check_level(level)
				checked += 1
		assert_signal_not_emitted(content, "pack_failed")
	return checked


func _check_level(level: LevelData) -> void:
	var words: PackedStringArray = level.bonus_words()
	for index: int in level.word_count():
		var text: String = level.word(index)
		words.append(text)
		var cells: Array[Vector2i] = level.word_cells(index)
		assert_eq(cells.size(), text.length(), level.get_id() + " " + text)
		for cell: Vector2i in cells:
			assert_true(Rect2i(Vector2i.ZERO, level.grid_size()).has_point(cell), str(cell))
	for text: String in words:
		var tiles: PackedInt32Array = _pick_tiles(level, text)
		assert_eq(level.spell(tiles), text, level.get_id() + " cannot form " + text)
	_play_level(level)


func _play_level(level: LevelData) -> BoardState:
	var board: BoardState = BoardState.new(level)
	watch_signals(board)
	var occupied: Array[Vector2i] = []
	for index: int in level.word_count():
		var word: String = level.word(index)
		var result: AttemptResult = board.evaluate(_pick_tiles(level, word))
		assert_not_null(result, level.get_id() + " " + word)
		if result == null:
			continue
		assert_true(
			result.kind in [AttemptResult.Kind.LEVEL, AttemptResult.Kind.ALREADY_FOUND],
			level.get_id() + " cannot play " + word
		)
		assert_true(word in board.found_words(), level.get_id() + " missing " + word)
		for cell: Vector2i in level.word_cells(index):
			if cell not in occupied:
				occupied.append(cell)
	assert_true(board.is_complete(), level.get_id() + " must complete without hints")
	assert_eq(board.found_words().size(), level.word_count())
	assert_eq(board.revealed_cells().size(), occupied.size())
	for cell: Vector2i in occupied:
		assert_true(cell in board.revealed_cells(), level.get_id() + " " + str(cell))
	assert_signal_emit_count(board, "completed", 1)
	var snapshot: Dictionary = board.to_dict()
	var repeated: AttemptResult = board.evaluate(_pick_tiles(level, level.word(0)))
	assert_not_null(repeated)
	if repeated != null:
		assert_eq(repeated.kind, AttemptResult.Kind.ALREADY_FOUND)
	assert_eq_deep(board.to_dict(), snapshot)
	assert_signal_emit_count(board, "completed", 1)
	return board


# Greedy pick is enough: tiles with the same letter are interchangeable. Empty when unformable.
func _pick_tiles(level: LevelData, text: String) -> PackedInt32Array:
	var tiles: PackedInt32Array = PackedInt32Array()
	for letter: String in text:
		var found: int = -1
		for tile: int in level.tile_count():
			if level.tile_letter(tile) == letter and not tiles.has(tile):
				found = tile
				break
		if found < 0:
			return PackedInt32Array()
		tiles.append(found)
	return tiles
