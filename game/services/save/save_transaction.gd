class_name SaveTransaction
extends RefCounted
## @api Opaque lease. Only its issuing Save's private identity record certifies it.

var _request: Dictionary = {}
var _view: Dictionary = {}


func request() -> Dictionary:
	return _request.duplicate(true)


func committed_view() -> Dictionary:
	return _view.duplicate(true)
