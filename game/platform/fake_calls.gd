class_name FakeCalls
extends RefCounted
## @api Deterministic Fake call log. Dictionaries and arrays are copied on recording.

var entries: Array[Dictionary] = []


func record(method: String, arguments: Array = []) -> void:
	entries.append({"method": method, "arguments": arguments.duplicate(true)})
