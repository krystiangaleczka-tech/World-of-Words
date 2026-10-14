class_name AppBackground
extends RefCounted
## Built-in Android Activity bridge; no plugin, permission or quit fallback.


func request() -> Error:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return ERR_UNAVAILABLE
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.call("getActivity")
	if activity == null:
		return ERR_UNAVAILABLE
	return OK if activity.call("moveTaskToBack", true) == true else ERR_UNAVAILABLE
