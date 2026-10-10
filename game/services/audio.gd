extends ServiceStub
## Named P1 sound effects. All streams/voices are prepared before play().

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const REGISTRY: String = "res://data/audio/cues.json"

var _save: SAVE_SCRIPT
var _sink: Callable
var _entries: Dictionary = {}
var _streams: Dictionary = {}
var _gains: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_gains: PackedFloat32Array = PackedFloat32Array()
var _next_voice: int = 0


## @api Inject live settings and an optional test sink(cue, linear_gain, pitch).
func configure(save: SAVE_SCRIPT, sink: Callable = Callable()) -> void:
	_disconnect_settings()
	_save = save
	_sink = sink
	if _save != null:
		_save.setting_changed.connect(_on_setting_changed)
	_refresh_volume()


## @api Atomically validate/preload the registry; retain existing cues on failure.
func load_cues(path: String = REGISTRY) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ERR_FILE_NOT_FOUND
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return ERR_INVALID_DATA
	var data: Dictionary = json.data
	if (
		data.size() != 3
		or not _number(data.get("schema_version"), 1.0, 1.0)
		or not _number(data.get("max_voices"), 1.0, 16.0)
		or float(data["max_voices"]) != floorf(float(data["max_voices"]))
		or not data.get("cues") is Dictionary
		or (data["cues"] as Dictionary).is_empty()
	):
		return ERR_INVALID_DATA
	var entries: Dictionary = data["cues"]
	var streams: Dictionary = {}
	var gains: Dictionary = {}
	var error: Error = _preload(entries, streams, gains)
	if error != OK:
		return error
	_clear_voices()
	_entries = entries
	_streams = streams
	_gains = gains
	for index: int in int(data["max_voices"]):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Sfx%d" % index
		add_child(voice)
		_voices.append(voice)
	_voice_gains.resize(_voices.size())
	_voice_gains.fill(0.0)
	_next_voice = 0
	return OK


func _preload(entries: Dictionary, streams: Dictionary, gains: Dictionary) -> Error:
	var names: RegEx = RegEx.new()
	names.compile("^[a-z][a-z0-9_]*$")
	var paths: RegEx = RegEx.new()
	paths.compile("^res://assets/audio/p1/[a-z_]+\\.wav$")
	for name: String in entries:
		var entry: Variant = entries[name]
		if names.search(name) == null or not _entry_valid(entry, paths):
			return ERR_INVALID_DATA
		var source: String = entry["files"][0]
		if not ResourceLoader.exists(source, "AudioStream"):
			return ERR_FILE_NOT_FOUND
		var stream: AudioStream = load(source) as AudioStream
		if stream == null:
			return ERR_FILE_CORRUPT
		streams[name] = stream
		gains[name] = db_to_linear(float(entry["volume_db"]))
	return OK


func _entry_valid(value: Variant, paths: RegEx) -> bool:
	if not value is Dictionary:
		return false
	var entry: Dictionary = value
	var files: Variant = entry.get("files")
	return (
		entry.size() == 3
		and files is Array
		and files.size() == 1
		and files[0] is String
		and paths.search(files[0]) != null
		and _number(entry.get("volume_db"), -60.0, 0.0)
		and _number(entry.get("pitch_scale"), 0.5, 2.0)
	)


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) >= minimum
		and float(value) <= maximum
	)


## @api No I/O or allocation; false means this request is unknown/unready/muted.
func play(cue: StringName) -> bool:
	var volume: float = _volume()
	if volume <= 0.0 or not _entries.has(cue):
		return false
	var gain: float = float(_gains[cue])
	var pitch: float = float(_entries[cue]["pitch_scale"])
	if _sink.is_valid():
		_sink.call(cue, gain * volume, pitch)
	else:
		var voice: AudioStreamPlayer = _voices[_next_voice]
		voice.stop()
		voice.stream = _streams[cue]
		voice.volume_linear = gain * volume
		voice.pitch_scale = pitch
		_voice_gains[_next_voice] = gain
		voice.play()
		_next_voice = (_next_voice + 1) % _voices.size()
	return true


func _volume() -> float:
	return float(_save.get_setting(&"sfx_volume")) if _save != null and _save.is_loaded() else 0.0


func _refresh_volume() -> void:
	var volume: float = _volume()
	for index: int in _voices.size():
		_voices[index].volume_linear = volume * _voice_gains[index]
		if volume <= 0.0:
			_voices[index].stop()


func _on_setting_changed(key: StringName) -> void:
	if key == &"sfx_volume":
		_refresh_volume()


func _disconnect_settings() -> void:
	if _save != null and _save.setting_changed.is_connected(_on_setting_changed):
		_save.setting_changed.disconnect(_on_setting_changed)


func _clear_voices() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		remove_child(voice)
		voice.queue_free()
	_voices.clear()
	_voice_gains.clear()


func _exit_tree() -> void:
	_disconnect_settings()
