extends ServiceStub
## @api Content autoload: manifest, campaign packs on demand, LevelData by slot.
## ARCHITECTURE.md#content.
## Loading is explicit (Nav calls load_manifest); a broken pack fails softly via pack_failed.

## @api A pack could not be read, failed its hash in debug, or did not match the manifest.
signal pack_failed(file: String, error: Error)

const SCHEMA_VERSION: int = 1
const PACK_PATH: String = "packs/"

var _language: String = ""
var _directory: String = ""
var _content_version: int = 0
var _slots: int = 0
var _packs: Array[Dictionary] = []
var _cached_file: String = ""
var _cached_levels: Array[LevelData] = []
var _check_hashes: bool = OS.is_debug_build()


## @api Read <root>/<language>/manifest.json. On any error the previous manifest stays active.
func load_manifest(language: String, root: String = "res://content") -> Error:
	var directory: String = root.path_join(language)
	var path: String = directory.path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	var manifest: Dictionary = data
	if (
		_positive(manifest.get("schema_version")) != SCHEMA_VERSION
		or not manifest.get("lang") is String
		or manifest["lang"] != language
	):
		return ERR_INVALID_DATA
	var version: int = _positive(manifest.get("content_version"))
	var slots: int = _positive(manifest.get("slots"))
	var packs: Array[Dictionary] = _read_packs(manifest.get("packs"), slots)
	if version < 1 or slots < 1 or packs.is_empty():
		return ERR_INVALID_DATA
	_language = language
	_directory = directory
	_content_version = version
	_slots = slots
	_packs = packs
	_cached_file = ""
	_cached_levels = []
	return OK


## @api True once a manifest has loaded.
func is_loaded() -> bool:
	return _slots > 0


## @api Language of the loaded manifest; "" before load.
func get_language() -> String:
	return _language


## @api Manifest content_version (FR-ANL-03); 0 before load.
func content_version() -> int:
	return _content_version


## @api Number of campaign slots in the loaded manifest.
func slot_count() -> int:
	return _slots


## @api Level for a campaign slot, or null. A slot outside 1..slot_count() is null without a signal.
func level_for_slot(slot: int) -> LevelData:
	if slot < 1 or slot > _slots:
		return null
	for pack: Dictionary in _packs:
		if slot >= pack["first"] and slot <= pack["last"]:
			if _cached_file != pack["file"] and not _load_pack(pack):
				return null
			return _cached_levels[slot - int(pack["first"])]
	return null


func _read_packs(value: Variant, slots: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var next: int = 1
	for entry: Variant in value:
		if not entry is Dictionary:
			return []
		var pack: Dictionary = entry
		var file: Variant = pack.get("file")
		var first: int = _positive(pack.get("first"))
		var last: int = _positive(pack.get("last"))
		if (
			not file is String
			or not _safe_path(file)
			or not pack.get("kind") is String
			or pack["kind"] != "campaign"
		):
			return []
		if not pack.get("sha256") is String or first != next or last < first:
			return []
		result.append({"file": file, "first": first, "last": last, "sha256": pack["sha256"]})
		next = last + 1
	if next != slots + 1:
		return []
	return result


func _load_pack(pack: Dictionary) -> bool:
	var file: String = pack["file"]
	var levels: Array[LevelData] = []
	var error: Error = _read_levels(_directory.path_join(file), pack, levels)
	if error != OK:
		pack_failed.emit(file, error)
		return false
	_cached_file = file
	_cached_levels = levels
	return true


func _read_levels(path: String, pack: Dictionary, levels: Array[LevelData]) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	if _check_hashes and FileAccess.get_sha256(path) != (pack["sha256"] as String).to_lower():
		return ERR_FILE_CORRUPT
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	var header: Dictionary = data
	if not _header_ok(header, pack):
		return ERR_INVALID_DATA
	var entries: Array = header["levels"]
	var first: int = pack["first"]
	for index: int in entries.size():
		var level: LevelData = null
		if entries[index] is Dictionary:
			level = LevelData.from_dict(entries[index])
		if level == null or level.get_slot() != first + index:
			return ERR_INVALID_DATA
		levels.append(level)
	return OK


func _header_ok(header: Dictionary, pack: Dictionary) -> bool:
	if (
		_positive(header.get("schema_version")) != SCHEMA_VERSION
		or not header.get("lang") is String
		or header["lang"] != _language
	):
		return false
	if (
		not header.get("kind") is String
		or header["kind"] != "campaign"
		or not header.get("levels") is Array
	):
		return false
	return (header["levels"] as Array).size() == int(pack["last"]) - int(pack["first"]) + 1


func _safe_path(file: String) -> bool:
	return (
		file.begins_with(PACK_PATH)
		and file.get_extension() == "json"
		and not file.contains("..")
		and file.count("/") == 1
	)


static func _positive(value: Variant) -> int:
	if not (value is float or value is int):
		return 0
	var number: float = float(value)
	if number != floorf(number) or number < 1:
		return 0
	return int(number)
