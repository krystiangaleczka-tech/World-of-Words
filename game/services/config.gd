extends ServiceStub
## @api Registry defaults loaded explicitly by Nav; initialization remains inert.

var _registry: ConfigRegistry = ConfigRegistry.new()


## @api Load sorted prefix JSON files atomically. Any invalid file keeps the prior registry.
## No remote/cache I/O until T-0254; schema is under services/config, outside this directory.
func load(directory: String = "res://data/config") -> Error:
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return ERR_CANT_OPEN
	var files: PackedStringArray = folder.get_files()
	files.sort()
	var candidate: ConfigRegistry = ConfigRegistry.new()
	var count: int = 0
	for filename: String in files:
		if filename.get_extension() != "json":
			continue
		var file: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()
		var parser: JSON = JSON.new()
		var error: Error = parser.parse(file.get_as_text())
		file.close()
		if error != OK or not parser.data is Dictionary:
			return ERR_PARSE_ERROR
		error = candidate.append_document(filename.get_basename(), parser.data as Dictionary)
		if error != OK:
			return error
		count += 1
	if count == 0:
		return ERR_FILE_NOT_FOUND
	_registry = candidate
	return OK


## @api Test for a registered key without emitting errors.
func has_key(key: StringName) -> bool:
	return _registry.has_key(key)


## @api Read an int default; unknown/wrong-type reads fail loudly in debug builds.
func get_int(key: StringName) -> int:
	return int(_registry.read_value(key, &"int", 0))


## @api Read a float default; integers are not silently coerced to float keys.
func get_float(key: StringName) -> float:
	return float(_registry.read_value(key, &"float", 0.0))


## @api Read a bool default with strict registry type checking.
func get_bool(key: StringName) -> bool:
	return bool(_registry.read_value(key, &"bool", false))


## @api Read a string default with strict registry type checking.
func get_string(key: StringName) -> String:
	return str(_registry.read_value(key, &"string", ""))
