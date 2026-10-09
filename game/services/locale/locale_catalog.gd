class_name LocaleCatalog
extends RefCounted
## Discover imported CSV translations through export-aware resource paths.
## Owners register independent copies; no project.godot per-file entries.

var _owned: Array[Translation] = []


func register_all(directory: String = "res://locale") -> Error:
	if not _owned.is_empty():
		return OK
	if not DirAccess.dir_exists_absolute(directory):
		return ERR_FILE_NOT_FOUND
	var files: PackedStringArray = ResourceLoader.list_directory(directory)
	files.sort()
	var pending: Array[Translation] = []
	for file: String in files:
		if not file.ends_with(".translation"):
			continue
		var source: Resource = ResourceLoader.load(
			directory.path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE
		)
		if not source is Translation:
			return ERR_FILE_CORRUPT
		pending.append(source.duplicate() as Translation)
	if pending.is_empty():
		return ERR_FILE_NOT_FOUND
	for copy: Translation in pending:
		TranslationServer.add_translation(copy)
	_owned = pending
	return OK


func unregister() -> void:
	for copy: Translation in _owned:
		TranslationServer.remove_translation(copy)
	_owned.clear()
