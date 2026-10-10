class_name SaveStorage
extends RefCounted
## @api JSON file storage; override checkpoint in tests to interrupt each write boundary.

var path: String


func _init(save_path: String = "user://save.json") -> void:
	path = save_path


## @api Read a JSON object without error-log noise; {} means unavailable/invalid.
func read_document(suffix: String = "") -> Dictionary:
	var file: FileAccess = FileAccess.open(path + suffix, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {}
	return parser.data as Dictionary


## @api Whether any primary/recovery file exists (first install versus corrupt save).
func has_any_file() -> bool:
	return (
		FileAccess.file_exists(path)
		or FileAccess.file_exists(path + ".tmp")
		or FileAccess.file_exists(path + ".bak")
	)


## @api Preserve the validated recovered temp before its path is reused for output.
func promote_temp() -> Error:
	return DirAccess.rename_absolute(path + ".tmp", path)


## @api Write temp -> flush -> primary to backup -> temp to primary. Return I/O errors.
## rotate_primary is false after backup recovery; a promoted valid temp may rotate safely.
func commit(text: String, rotate_primary: bool) -> Error:
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var error: Error = checkpoint(&"temp_opened")
	if error == OK:
		file.store_string(text)
		error = file.get_error()
	if error == OK:
		error = checkpoint(&"temp_written")
	if error == OK:
		file.flush()
		error = file.get_error()
	file.close()
	if error == OK:
		error = checkpoint(&"temp_flushed")
	if error == OK and rotate_primary and FileAccess.file_exists(path):
		error = DirAccess.rename_absolute(path, path + ".bak")
	if error == OK:
		error = checkpoint(&"backup_rotated")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK:
		error = checkpoint(&"primary_promoted")
	return error


## @api Test seam. Production performs no extra work at a write boundary.
func checkpoint(_step: StringName) -> Error:
	return OK
