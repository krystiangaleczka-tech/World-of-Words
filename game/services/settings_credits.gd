class_name SettingsCredits
extends RefCounted
## Offline legal data, original-language notices. T-0288 owns presentation.

const FONT: Resource = preload("res://assets/fonts/font_license.tres")
const ICONS: Resource = preload("res://assets/icons/icon_license.tres")
const AUDIO: Resource = preload("res://assets/audio/p1/audio_notice.tres")
const CONTENT: Resource = preload("res://content/source_notice.tres")


## @api Fresh copied catalog; no caller receives shared mutable resources.
static func entries() -> Array[Dictionary]:
	var licenses: Dictionary = Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	var license_notices: PackedStringArray = []
	for name: String in names:
		license_notices.append(name + "\n" + String(licenses[name]))
	return [
		{"id": &"godot", "notice": Engine.get_license_text()},
		{"id": &"godot-copyrights", "notice": JSON.stringify(Engine.get_copyright_info(), "\t")},
		{"id": &"godot-licenses", "notice": "\n\n".join(license_notices)},
		{"id": &"inter", "notice": String(FONT.get_meta(&"ofl_notice"))},
		{"id": &"lucide", "notice": String(ICONS.get_meta(&"license_notice"))},
		{"id": &"audio", "notice": String(AUDIO.get_meta(&"notice"))},
		{"id": &"pl-sources", "notice": String(CONTENT.get_meta(&"notice"))}
	]
