class_name AdPresentation
extends Node
## Internal Fake-era presentation owner; no boot/UI activation or IAP processing.

signal telemetry(name: StringName, params: Dictionary)
signal changed
signal finished
signal audio_paused(paused: bool)
signal interstitial_opened

const OPERATION_TIMEOUT_SECONDS: float = 120.0
const ECONOMY: Script = preload("res://services/economy.gd")
const SAVE: Script = preload("res://services/save.gd")

var _ads: AdsAdapter
var _timer: Timer
var _kind: StringName = &"idle"
var _interstitial_ready: bool = false
var _reward: Callable
var _placement: StringName
var _earned: bool = false
var _opened: bool = false
var _reward_error: Error = OK
var _owner: ECONOMY
var _reason: StringName
var _amounts: Dictionary = {}
var _unavailable: bool = false
var _generation: int = 0
var _failed_generation: int = -1
var _reserve: Callable
var _reserved: bool = false
var _save: SAVE
var _settling: bool = false
var _notifying: bool = false
var _dispatching: bool = false


func configure(ads: AdsAdapter, reserve: Callable, save: SAVE) -> void:
	_ads = ads
	_reserve = reserve
	_save = save
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.ignore_time_scale = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.wait_time = OPERATION_TIMEOUT_SECONDS
	add_child(_timer)
	_timer.timeout.connect(expire)
	_ads.interstitial_loaded.connect(_on_interstitial_loaded)
	_ads.rewarded_loaded.connect(_on_rewarded_loaded)
	_ads.ad_opened.connect(_on_opened)
	_ads.reward_earned.connect(_on_reward)
	_ads.ad_closed.connect(_on_closed)
	_ads.ad_failed.connect(_on_failed)


func busy() -> bool:
	return _dispatching or _notifying or _kind not in [&"idle", &"preload"]


func interstitial_ready() -> bool:
	return _interstitial_ready and not busy()


func rewarded_state() -> StringName:
	if _kind == &"pending_reward":
		return &"pending_reward"
	if _kind not in [&"idle", &"preload"]:
		return &"busy"
	return &"unavailable" if _unavailable else &"ready"


func can_retry(placement: StringName, reward: Callable) -> bool:
	return _kind == &"pending_reward" and _same_reward(placement, reward)


func begin_shop_visit() -> void:
	if _kind == &"idle":
		_unavailable = false


func prepare_interstitial() -> void:
	if _kind != &"idle" or _interstitial_ready:
		return
	_kind = &"preload"
	_timer.start()
	_ads.load_interstitial()


func show_interstitial() -> void:
	_generation += 1
	_kind = &"interstitial"
	_interstitial_ready = false
	_opened = false
	_placement = &"campaign_continue"
	_timer.start()
	_observe(&"ad_offer_shown", {"placement": str(_placement), "ad_format": "interstitial"})
	_ads.show_interstitial()


func request_rewarded(placement: StringName, reward: Callable) -> Error:
	if _settling or _dispatching or _notifying:
		return ERR_BUSY
	if _kind == &"pending_reward":
		if not _same_reward(placement, reward):
			return ERR_BUSY
		var result: Error = _settle_reward()
		if result == OK:
			_kind = &"idle"
		return result
	if busy():
		return ERR_BUSY
	if not _valid_reward(reward):
		return ERR_INVALID_PARAMETER
	var arguments: Array = reward.get_bound_arguments()
	_placement = placement
	_generation += 1
	_owner = reward.get_object()
	_reason = StringName(arguments[0])
	_amounts = arguments[1].duplicate(true)
	_reward = _owner.grant.bind(_reason, _amounts.duplicate(true))
	_earned = false
	_reserved = false
	_reward_error = OK
	_opened = false
	_kind = &"reward_loading"
	_timer.start()
	_dispatching = true
	var generation: int = _generation
	changed.emit()
	if _generation == generation and _kind == &"reward_loading":
		_ads.load_rewarded()
	_dispatching = false
	changed.emit()
	return OK


func _valid_reward(reward: Callable) -> bool:
	if (
		not reward.is_valid()
		or not reward.get_object() is ECONOMY
		or reward.get_method() != &"grant"
		or reward.get_bound_arguments_count() != 2
		or reward.get_unbound_arguments_count() != 0
	):
		return false
	var arguments: Array = reward.get_bound_arguments()
	var owner: ECONOMY = reward.get_object()
	return (
		owner.is_ready()
		and owner.atomic_save_matches(_save)
		and not owner.atomic_has_pending()
		and (arguments[0] is String or arguments[0] is StringName)
		and not str(arguments[0]).is_empty()
		and str(arguments[0]) == str(arguments[0]).strip_edges()
		and arguments[1] is Dictionary
		and WalletSnapshot.valid_amounts(arguments[1])
	)


func _same_reward(placement: StringName, reward: Callable) -> bool:
	if not reward.is_valid() or reward.get_object() != _owner or reward.get_method() != &"grant":
		return false
	var arguments: Array = reward.get_bound_arguments()
	return (
		placement == _placement
		and arguments.size() == 2
		and arguments[0] == _reason
		and arguments[1] == _amounts
	)


func expire() -> void:
	if _kind == &"idle" or _kind == &"pending_reward":
		return
	_fail_active("timeout")


func _on_interstitial_loaded() -> void:
	if _kind != &"preload":
		return
	_timer.stop()
	_kind = &"idle"
	_interstitial_ready = true


func _on_rewarded_loaded() -> void:
	if _kind != &"reward_loading":
		return
	_kind = &"rewarded"
	_unavailable = false
	_timer.start()
	_ads.show_rewarded()


func _on_opened() -> void:
	if _kind not in [&"interstitial", &"rewarded"] or _opened:
		return
	_opened = true
	_observe(
		&"ad_shown",
		{
			"placement": str(_placement),
			"ad_format": "interstitial" if _kind == &"interstitial" else "rewarded"
		}
	)
	var generation: int = _generation
	if _kind == &"interstitial":
		interstitial_opened.emit()
	if _generation == generation and _opened:
		audio_paused.emit(true)


func _on_reward() -> void:
	if _kind != &"rewarded" or not _opened or _earned:
		return
	_earned = true
	var placement: String = str(_placement)
	_settle_reward()
	_observe(&"ad_reward_earned", {"placement": placement})


func _settle_reward() -> Error:
	if _settling:
		return ERR_BUSY
	_settling = true
	var result: Error = _commit_reward()
	_settling = false
	return result


func _commit_reward() -> Error:
	_reward_error = ERR_UNCONFIGURED
	if not _reward_owner_ready():
		return _reward_error
	_reward_error = ERR_BUSY
	if _placement == &"shop_coins" and not _reserved:
		_reward_error = _reserve.call()
		if _reward_error != OK:
			return _reward_error
		_reserved = true
	if not _reward_owner_ready():
		_reward_error = ERR_UNCONFIGURED
		return _reward_error
	var result: Variant = _reward.call() if _reward.is_valid() else ERR_UNCONFIGURED
	_reward_error = result if result is int else ERR_INVALID_DATA
	if _reward_error == OK:
		_reward = Callable()
		if _kind == &"pending_reward":
			_kind = &"idle"
	return _reward_error


func _reward_owner_ready() -> bool:
	return is_instance_valid(_owner) and _owner.is_ready() and _owner.atomic_save_matches(_save)


func _on_closed() -> void:
	if _kind in [&"interstitial", &"rewarded"]:
		_end()


func _on_failed(reason: String) -> void:
	if _kind in [&"preload", &"reward_loading", &"interstitial", &"rewarded"]:
		_fail_active("no_fill" if reason == "no_fill" else "provider_error")


func _end() -> void:
	_notifying = true
	var continuation: bool = _kind == &"interstitial"
	_unavailable = _kind in [&"reward_loading", &"rewarded"] and not _earned and not _opened
	_timer.stop()
	_generation += 1
	_kind = &"pending_reward" if _earned and _reward_error != OK else &"idle"
	if _kind != &"pending_reward":
		_reward = Callable()
	if _opened:
		_opened = false
		audio_paused.emit(false)
	changed.emit()
	_notifying = false
	if continuation:
		finished.emit()


func _exit_tree() -> void:
	if _opened:
		audio_paused.emit(false)
	_ads.interstitial_loaded.disconnect(_on_interstitial_loaded)
	_ads.rewarded_loaded.disconnect(_on_rewarded_loaded)
	_ads.ad_opened.disconnect(_on_opened)
	_ads.reward_earned.disconnect(_on_reward)
	_ads.ad_closed.disconnect(_on_closed)
	_ads.ad_failed.disconnect(_on_failed)


func _failure(code: String) -> void:
	var interstitial: bool = _kind in [&"preload", &"interstitial"]
	_observe(
		&"ad_failed",
		{
			"placement": "campaign_continue" if interstitial else str(_placement),
			"ad_format": "interstitial" if interstitial else "rewarded",
			"error_code": code
		}
	)


func _observe(name: StringName, params: Dictionary) -> void:
	var previous: bool = _notifying
	_notifying = true
	telemetry.emit(name, params.duplicate(true))
	_notifying = previous


func _fail_active(code: String) -> void:
	var generation: int = _generation
	if _failed_generation == generation:
		return
	_failed_generation = generation
	_failure(code)
	# A synchronous observer may have closed/replaced the old operation.
	if _generation == generation:
		_end()
