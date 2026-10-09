extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const NAV_SCRIPT: Script = preload("res://services/nav.gd")
const BOOT_SCRIPT: Script = preload("res://services/nav/boot.gd")
const DIRECTORY: String = "user://t0132-locale"
const SAVE_PATH: String = "user://t0132-save.json"
var _locale: String
var _catalog: LocaleCatalog


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1_790_000_000


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_catalog = LocaleCatalog.new()
	_clean()
	assert_eq(DirAccess.make_dir_recursive_absolute(DIRECTORY), OK)


func after_each() -> void:
	_catalog.unregister()
	TranslationServer.set_locale(_locale)
	_clean()


func _clean() -> void:
	var directory: DirAccess = DirAccess.open(DIRECTORY)
	if directory != null:
		DirAccess.remove_absolute(DIRECTORY.path_join("pl/manifest.json"))
		DirAccess.remove_absolute(DIRECTORY.path_join("pl"))
		for file: String in directory.get_files():
			DirAccess.remove_absolute(DIRECTORY.path_join(file))
		DirAccess.remove_absolute(DIRECTORY)
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)


func _translation(language: String, key: String, value: String) -> Translation:
	var result: Translation = Translation.new()
	result.set_locale(language)
	result.add_message(key, value)
	return result


func test_new_area_imports_register_without_project_entries() -> void:
	for language: String in ["pl", "en"]:
		var copy: Translation = _translation(language, "probe.shell.title", "Area " + language)
		assert_eq(
			ResourceSaver.save(copy, DIRECTORY.path_join("probe." + language + ".translation")), OK
		)
	var csv: FileAccess = FileAccess.open(DIRECTORY.path_join("probe.csv"), FileAccess.WRITE)
	csv.store_string("keys,pl,en\nprobe.shell.title,Area pl,Area en\n")
	csv.close()
	assert_eq(_catalog.register_all(DIRECTORY), OK)
	assert_eq(_catalog.register_all(DIRECTORY), OK)
	for language: String in ["pl", "en"]:
		TranslationServer.set_locale(language)
		assert_eq(TranslationServer.translate("probe.shell.title"), "Area " + language)
	_catalog.unregister()
	assert_eq(TranslationServer.translate("probe.shell.title"), "probe.shell.title")


func test_actual_csv_areas_translate_polish_and_english() -> void:
	assert_eq(_catalog.register_all(), OK)
	TranslationServer.set_locale("pl")
	assert_eq(TranslationServer.translate("level.complete.title"), "Poziom ukończony")
	assert_eq(TranslationServer.translate("debug.shell.home"), "Menu")
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate("level.complete.title"), "Level complete")
	assert_eq(TranslationServer.translate("debug.shell.title"), "Developer tools")


func test_unregister_preserves_another_owner() -> void:
	var outside: Translation = _translation("pl", "probe.shell.title", "Outside")
	TranslationServer.add_translation(outside)
	var imported: Translation = _translation("pl", "probe.shell.title", "Inside")
	assert_eq(ResourceSaver.save(imported, DIRECTORY.path_join("probe.pl.translation")), OK)
	assert_eq(_catalog.register_all(DIRECTORY), OK)
	_catalog.unregister()
	TranslationServer.set_locale("pl")
	assert_eq(TranslationServer.translate("probe.shell.title"), "Outside")
	TranslationServer.remove_translation(outside)


func test_invalid_import_does_not_register_partial_catalog() -> void:
	var copy: Translation = _translation("pl", "probe.shell.title", "Partial")
	assert_eq(ResourceSaver.save(copy, DIRECTORY.path_join("a.pl.translation")), OK)
	assert_eq(ResourceSaver.save(Resource.new(), DIRECTORY.path_join("broken.res")), OK)
	assert_eq(
		DirAccess.rename_absolute(
			DIRECTORY.path_join("broken.res"), DIRECTORY.path_join("z.pl.translation")
		),
		OK
	)
	assert_eq(_catalog.register_all(DIRECTORY), ERR_FILE_CORRUPT)
	TranslationServer.set_locale("pl")
	assert_eq(TranslationServer.translate("probe.shell.title"), "probe.shell.title")
	assert_eq(DirAccess.remove_absolute(DIRECTORY.path_join("z.pl.translation")), OK)
	assert_eq(_catalog.register_all(DIRECTORY), OK, "failed attempt can retry")
	assert_eq(TranslationServer.translate("probe.shell.title"), "Partial")


func test_csv_keys_match_area_and_have_both_languages() -> void:
	var pattern: RegEx = RegEx.new()
	assert_eq(pattern.compile("^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*$"), OK)
	var keys: PackedStringArray = []
	for name: String in ResourceLoader.list_directory("res://locale"):
		if not name.ends_with(".csv"):
			continue
		var csv: FileAccess = FileAccess.open("res://locale/" + name, FileAccess.READ)
		assert_eq(csv.get_csv_line(), PackedStringArray(["keys", "pl", "en"]))
		while not csv.eof_reached():
			var row: PackedStringArray = csv.get_csv_line()
			if row == PackedStringArray([""]):
				continue
			assert_eq(row.size(), 3)
			if row.size() != 3:
				continue
			assert_not_null(pattern.search(row[0]), row[0])
			assert_true(row[0].begins_with(name.get_basename() + "."))
			assert_false(row[0] in keys, "unique English keys")
			keys.append(row[0])
			assert_false(row[1].strip_edges().is_empty())
			assert_false(row[2].strip_edges().is_empty())
		csv.close()
	assert_gt(keys.size(), 0)


func test_boot_registers_before_first_screen_and_uses_saved_language() -> void:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	for service: ServiceStub in [save, config, content]:
		add_child_autofree(service)
		service.initialize(FixedClock.new())
	save.configure(
		SaveStorage.new(SAVE_PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	Nav.configure(save, config, content)
	Nav.configure_screens(
		func(_screen: int) -> Node:
			var label: Label = Label.new()
			label.text = TranslationServer.translate("debug.shell.title")
			return label
	)
	TranslationServer.set_locale("en")
	var boot: Node = BOOT_SCRIPT.new()
	boot.set("content_root", "res://tests/fixtures/content")
	add_child(boot)
	assert_eq(Nav.current_screen(), Nav.Screen.LEVEL)
	assert_eq(TranslationServer.get_locale(), "pl")
	assert_eq((Nav.mounted_screen() as Label).text, "Narzędzia debugowania")
	remove_child(boot)
	boot.free()
	assert_eq(
		TranslationServer.translate("debug.shell.title"),
		"debug.shell.title",
		"boot releases its copies"
	)
	Nav.configure(Save, Config, Content)
	Nav.configure_screens(Callable())


func test_missing_and_empty_catalogue_are_errors() -> void:
	assert_eq(_catalog.register_all(DIRECTORY), ERR_FILE_NOT_FOUND)
	assert_eq(_catalog.register_all(DIRECTORY.path_join("missing")), ERR_FILE_NOT_FOUND)


func test_failed_navigation_keeps_previous_locale() -> void:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	var nav: NAV_SCRIPT = NAV_SCRIPT.new()
	var host: Node = Node.new()
	add_child_autofree(host)
	for service: ServiceStub in [save, config, content, nav]:
		add_child_autofree(service)
		service.initialize(FixedClock.new())
	save.configure(
		SaveStorage.new(SAVE_PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	nav.configure(save, config, content)
	TranslationServer.set_locale("en")
	assert_eq(nav.start(host, "res://tests/fixtures/missing"), ERR_FILE_NOT_FOUND)
	assert_eq(TranslationServer.get_locale(), "en")

	assert_eq(DirAccess.make_dir_recursive_absolute(DIRECTORY.path_join("pl")), OK)
	assert_eq(
		DirAccess.copy_absolute(
			"res://tests/fixtures/content/pl/manifest.json", DIRECTORY.path_join("pl/manifest.json")
		),
		OK
	)
	assert_eq(
		nav.start(host, DIRECTORY), ERR_INVALID_PARAMETER, "valid manifest, missing first pack"
	)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.BOOT)
	assert_eq(TranslationServer.get_locale(), "en")
