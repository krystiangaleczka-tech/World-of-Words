class_name LevelCopy
extends RefCounted
## Imported resources remain exportable; each owner registers independent copies.

const PL: Translation = preload("res://locale/level.pl.translation")
const EN: Translation = preload("res://locale/level.en.translation")

var _owned: Array[Translation] = []


func register() -> void:
	if not _owned.is_empty():
		return
	for source: Translation in [PL, EN]:
		var copy: Translation = source.duplicate() as Translation
		_owned.append(copy)
		TranslationServer.add_translation(copy)


func unregister() -> void:
	for copy: Translation in _owned:
		TranslationServer.remove_translation(copy)
	_owned.clear()
