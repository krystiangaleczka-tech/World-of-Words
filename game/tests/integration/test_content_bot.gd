extends GutTest
## Bot pass over every shippable level (FR-CONT-07). Upgraded to BoardState play in T-0119.

const CONTENT_SCRIPT = preload("res://services/content.gd")
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
