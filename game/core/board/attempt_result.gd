class_name AttemptResult
extends RefCounted
## @api One evaluated attempt; null instead means ignored (fewer than three tiles).

enum Kind { LEVEL, BONUS, ALREADY_FOUND, INVALID }

var kind: Kind = Kind.INVALID
var word: String = ""
var cells_to_reveal: Array[Vector2i] = []


func _init(value: Kind = Kind.INVALID, text: String = "") -> void:
	kind = value
	word = text
