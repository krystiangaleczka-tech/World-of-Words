extends RefCounted
## Debug-only service boundary. Never replaces adapters or fabricates purchases.

const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const PLATFORM: Script = preload("res://platform/platform.gd")
var _save: SAVE
var _economy: ECONOMY
var _config: CONFIG
var _platform: PLATFORM
var _enabled: bool = true
var _pending: Dictionary = {}
var _busy: bool = false


func configure(
	save: SAVE, economy: ECONOMY, config: CONFIG, platform: PLATFORM, enabled: bool = true
) -> void:
	if _busy or not _pending.is_empty():
		return
	_save = save
	_economy = economy
	_config = config
	_platform = platform
	_enabled = enabled


func matches_save(save: SAVE) -> bool:
	return _allowed() and _save == save and _economy.atomic_save_matches(save)


func _allowed() -> bool:
	return (
		OS.is_debug_build()
		and _enabled
		and is_instance_valid(_save)
		and is_instance_valid(_economy)
		and is_instance_valid(_config)
		and is_instance_valid(_platform)
	)


func snapshot() -> Dictionary:
	if not matches_save(_save) or not _save.is_loaded():
		return {}
	var view: Dictionary = _save.committed_view()
	if view.error != OK:
		return {}
	return {
		"wallet": _economy.snapshot(),
		"remove_forced_ads": view.sections.monetization.remove_forced_ads,
		"retry": not _pending.is_empty()
	}


func coin_step() -> int:
	return _config.get_int(&"economy.price.hint") if _allowed() else 0


func modify(item: String, amount: int, remove: bool = false) -> Error:
	if not matches_save(_save):
		return ERR_UNAVAILABLE
	if _busy or not _pending.is_empty():
		return ERR_BUSY
	if item not in WalletSnapshot.KEYS or amount <= 0:
		return ERR_INVALID_PARAMETER
	return (
		(OK if _economy.spend(&"debug", {item: amount}) else ERR_UNAVAILABLE)
		if remove
		else _economy.grant(&"debug", {item: amount})
	)


# gdlint: disable=max-returns
func set_remove_forced_ads(value: bool) -> Error:
	if not matches_save(_save) or not _save.is_loaded():
		return ERR_UNAVAILABLE
	if _busy or _save.writes_blocked():
		return ERR_BUSY
	var view: Dictionary = _save.committed_view()
	if view.error != OK:
		return ERR_UNAVAILABLE
	var before: Dictionary = view.sections.monetization
	if not _pending.is_empty() and value != _pending.target:
		return ERR_BUSY
	if (
		_save.get_section(&"monetization") != before
		or _save.get_section(&"economy") != view.sections.economy
	):
		return ERR_BUSY
	if before.remove_forced_ads == value:
		_pending.clear()
		return OK
	if not _pending.is_empty() and _pending.before != before:
		_pending.clear()
		return ERR_BUSY
	var candidate: Dictionary = before.duplicate(true)
	candidate.remove_forced_ads = value
	_busy = true
	var error: Error = _save.set_section(&"monetization", candidate)
	if error == OK:
		error = _save.flush()
		if error != OK:
			# Keep the target locally, not in Save's shared staging document.
			_save.set_section(&"monetization", before)
			_pending = {"target": value, "before": before}
	if error == OK:
		_pending.clear()
	_busy = false
	return error


func ad_outcome(outcome: StringName) -> Error:
	if not _allowed():
		return ERR_UNAVAILABLE
	var fake: AdsFake = _platform.ads as AdsFake
	if fake == null or outcome not in [&"fill", &"no_fill"]:
		return ERR_UNAVAILABLE
	var error: Error = fake.set_outcome(
		&"load_rewarded", &"ready" if outcome == &"fill" else &"no_fill"
	)
	if error == OK:
		error = fake.set_outcome(&"show_rewarded", &"reward" if outcome == &"fill" else &"no_fill")
	return error


func iap_outcome(outcome: StringName) -> Error:
	if not _allowed():
		return ERR_UNAVAILABLE
	var fake: IapFake = _platform.iap as IapFake
	return ERR_UNAVAILABLE if fake == null else fake.set_outcome(&"purchase", outcome)
