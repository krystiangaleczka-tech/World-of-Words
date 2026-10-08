extends LevelScreen
## Fixture-only debug gallery; never replaces production content.


class GalleryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK


func _ready() -> void:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	add_child(save)
	add_child(content)
	save.initialize(Clock.new())
	save.configure(GalleryStorage.new())
	save.load()
	content.load_manifest("pl", "res://tests/fixtures/content")
	var section: Dictionary = save.get_section(&"progress")
	section["by_lang"]["pl"]["current_slot"] = 2
	save.set_section(&"progress", section)
	configure(save, content, 2)
	super._ready()
