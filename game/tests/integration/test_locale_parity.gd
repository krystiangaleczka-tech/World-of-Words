extends GutTest

const DIRECTORY: String = "user://t0352-locale-parity"
const PROBE: StringName = &"probe.t0352.title"
const OUTSIDE: StringName = &"probe.t0352.outside"
var _locale: String
var _pseudo: bool
var _owners: Array[LocaleCatalog] = []
var _outside: Translation


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	TranslationServer.pseudolocalization_enabled = false
	_clean()


func after_each() -> void:
	for owner: LocaleCatalog in _owners:
		owner.unregister()
	_owners.clear()
	if _outside != null:
		TranslationServer.remove_translation(_outside)
	_outside = null
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	_clean()


func _clean() -> void:
	var directory: DirAccess = DirAccess.open(DIRECTORY)
	if directory == null:
		return
	for file: String in directory.get_files():
		DirAccess.remove_absolute(DIRECTORY.path_join(file))
	DirAccess.remove_absolute(DIRECTORY)


func _catalog() -> LocaleCatalog:
	var owner: LocaleCatalog = LocaleCatalog.new()
	_owners.append(owner)
	return owner


func _rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var files: PackedStringArray = ResourceLoader.list_directory("res://locale")
	files.sort()
	for file: String in files:
		if not file.ends_with(".csv"):
			continue
		var csv: FileAccess = FileAccess.open("res://locale/" + file, FileAccess.READ)
		assert_not_null(csv, file)
		if csv == null:
			continue
		assert_eq(csv.get_csv_line(), PackedStringArray(["keys", "pl", "en"]))
		while not csv.eof_reached():
			var row: PackedStringArray = csv.get_csv_line()
			if row == PackedStringArray([""]):
				continue
			assert_eq(row.size(), 3)
			if row.size() == 3:
				result.append(
					{"area": file.get_basename(), "key": row[0], "pl": row[1], "en": row[2]}
				)
		csv.close()
	assert_gt(result.size(), 0)
	return result


func _import(area: String, language: String) -> Translation:
	var path: String = "res://locale/%s.%s.translation" % [area, language]
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(resource is Translation, path)
	return resource as Translation


func test_every_imported_message_matches_exact_language_and_source() -> void:
	for row: Dictionary in _rows():
		for language: String in ["pl", "en"]:
			var translation: Translation = _import(row.area, language)
			if translation == null:
				continue
			assert_eq(translation.get_locale(), language, row.key)
			assert_eq(
				str(translation.get_message(row.key)), row[language], language + ":" + row.key
			)


func test_registered_catalog_matches_all_keys_over_repeated_locale_cycles() -> void:
	var rows: Array[Dictionary] = _rows()
	var catalog: LocaleCatalog = _catalog()
	assert_eq(catalog.register_all(), OK)
	for cycle: int in range(3):
		assert_eq(catalog.register_all(), OK)
		for language: String in ["pl", "en", "pl_PL", "en_US"]:
			TranslationServer.set_locale(language)
			for row: Dictionary in rows:
				assert_eq(
					str(TranslationServer.translate(row.key)),
					row[language.get_slice("_", 0)],
					"%s:%s:%s" % [cycle, language, row.key]
				)


func test_actual_formatted_copy_renders_source_and_import_with_count_boundaries() -> void:
	var token: RegEx = RegEx.new()
	assert_eq(token.compile("%(?:[-+0]*)(?:[0-9]+|\\*)?(?:\\.(?:[0-9]+|\\*))?([sdoxXfvc%])"), OK)
	var formatted: int = 0
	for row: Dictionary in _rows():
		for language: String in ["pl", "en"]:
			var source: String = row[language]
			var matches: Array[RegExMatch] = token.search_all(source)
			if matches.is_empty():
				continue
			var translation: Translation = _import(row.area, language)
			if translation == null:
				continue
			for count: int in [1, 2, 5, 21]:
				var arguments: Array = []
				for match_value: RegExMatch in matches:
					for width: int in range(match_value.get_string().count("*")):
						arguments.append(count)
					var kind: String = match_value.get_string(1)
					if kind == "s":
						arguments.append("Żółć")
					elif kind == "v":
						arguments.append(Vector2(count, count))
					elif kind != "%":
						arguments.append(count)
				var expected: String = source % arguments
				assert_false(expected.is_empty(), row.key)
				assert_eq(str(translation.get_message(row.key)) % arguments, expected, row.key)
			formatted += 1
	assert_gt(formatted, 0)


func _resource(language: String, message: String) -> void:
	var translation: Translation = Translation.new()
	translation.set_locale(language)
	translation.add_message(PROBE, message)
	assert_eq(
		ResourceSaver.save(translation, DIRECTORY.path_join("probe." + language + ".translation")),
		OK
	)


func _fixtures() -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(DIRECTORY), OK)
	_resource("pl", "Próba")
	_resource("en", "Probe")
	_outside = Translation.new()
	_outside.set_locale("pl")
	_outside.add_message(OUTSIDE, "Outside")
	TranslationServer.add_translation(_outside)


func test_two_owners_release_only_their_copies_and_preserve_outside_translation() -> void:
	_fixtures()
	var first: LocaleCatalog = _catalog()
	var second: LocaleCatalog = _catalog()
	assert_eq(first.register_all(DIRECTORY), OK)
	assert_eq(second.register_all(DIRECTORY), OK)
	first.unregister()
	first.unregister()
	for language: String in ["pl", "en"]:
		TranslationServer.set_locale(language)
		assert_eq(str(TranslationServer.translate(PROBE)), "Próba" if language == "pl" else "Probe")
	second.unregister()
	TranslationServer.set_locale("pl")
	assert_eq(TranslationServer.translate(PROBE), PROBE)
	assert_eq(str(TranslationServer.translate(OUTSIDE)), "Outside")


func test_corrupt_later_resource_rolls_back_both_languages_and_allows_repaired_retry() -> void:
	_fixtures()
	var bad: String = DIRECTORY.path_join("z.pl.translation")
	assert_eq(ResourceSaver.save(Resource.new(), DIRECTORY.path_join("bad.res")), OK)
	assert_eq(DirAccess.rename_absolute(DIRECTORY.path_join("bad.res"), bad), OK)
	var catalog: LocaleCatalog = _catalog()
	assert_eq(catalog.register_all(DIRECTORY), ERR_FILE_CORRUPT)
	for language: String in ["pl", "en"]:
		TranslationServer.set_locale(language)
		assert_eq(TranslationServer.translate(PROBE), PROBE)
	assert_eq(DirAccess.remove_absolute(bad), OK)
	assert_eq(catalog.register_all(DIRECTORY), OK)
	assert_eq(str(TranslationServer.translate(PROBE)), "Probe")
	TranslationServer.set_locale("pl")
	assert_eq(str(TranslationServer.translate(PROBE)), "Próba")
	assert_eq(str(TranslationServer.translate(OUTSIDE)), "Outside")
