extends ServiceStub
## @api Unactivated consent/ad flows against Fakes; transaction processing remains T-0271.

signal continuation_ready(completed_slot: int)
signal audio_pause_requested(paused: bool)

enum Step { IDLE, INFO, FORM, ATT, INITIALIZING }

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _save: SAVE_SCRIPT
var _config: CONFIG_SCRIPT
var _events: EVENTS_SCRIPT
var _consent: ConsentAdapter
var _ads: AdsAdapter
var _ios: bool = false
var _started: bool = false
var _step: Step = Step.IDLE
var _slot: int = 0
var _ump: ConsentAdapter.State = ConsentAdapter.State.UNKNOWN
var _att: ConsentAdapter.AttStatus = ConsentAdapter.AttStatus.UNKNOWN
var _sdk_ready: bool = false
var _presentation: AdPresentation
var _legal_timer: Timer
var _session_start: int = 0
var _prompts: int = 0
var _last_ad_slot: int = -1
var _last_ad_seconds: int = -1
var _levels_since_ad: int = 0
var _last_visit: String = ""
var _last_evaluated: String = ""
var _history_failed: bool = false
var _analytics_live: bool = false
var _shop_reservation: Dictionary = {}


## @api No implicit provider operation; reconfiguration disconnects old adapters.
func configure(
	save: SAVE_SCRIPT,
	config: CONFIG_SCRIPT,
	events: EVENTS_SCRIPT,
	consent: ConsentAdapter,
	ads: AdsAdapter,
	ios: bool
) -> Error:
	if (
		_slot > 0
		or _step != Step.IDLE
		or (is_instance_valid(_presentation) and _presentation.busy())
	):
		return ERR_BUSY
	if (
		not is_instance_valid(save)
		or not save.is_loaded()
		or not is_instance_valid(config)
		or not is_instance_valid(events)
		or consent == null
		or ads == null
		or get_clock() == null
		or not config.has_key(&"consent.ump_after_slot")
		or not config.has_key(&"consent.att_after_slot")
	):
		return ERR_UNCONFIGURED
	_disconnect()
	_save = save
	_config = config
	_events = events
	_consent = consent
	_ads = ads
	_ios = ios
	_started = false
	_ump = ConsentAdapter.State.UNKNOWN
	_att = ConsentAdapter.AttStatus.UNKNOWN
	_sdk_ready = false
	_session_start = get_clock().monotonic_msec() / 1000
	_prompts = 0
	_last_ad_slot = -1
	_last_ad_seconds = -1
	_last_visit = ""
	_last_evaluated = ""
	_history_failed = false
	_analytics_live = false
	_levels_since_ad = int(_save.get_section(&"monetization")["levels_since_interstitial"])
	_presentation = AdPresentation.new()
	add_child(_presentation)
	_presentation.configure(_ads, _reserve_shop_reward, _save)
	_presentation.finished.connect(_release)
	_presentation.audio_paused.connect(_relay_audio_pause)
	_presentation.interstitial_opened.connect(_on_interstitial_opened)
	_legal_timer = Timer.new()
	_legal_timer.one_shot = true
	_legal_timer.ignore_time_scale = true
	_legal_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_legal_timer.wait_time = AdPresentation.OPERATION_TIMEOUT_SECONDS
	add_child(_legal_timer)
	_legal_timer.timeout.connect(expire_operation)
	_consent.consent_resolved.connect(_on_consent)
	_consent.att_resolved.connect(_on_att)
	_consent.analytics_resolved.connect(_on_analytics)
	_consent.operation_failed.connect(expire_operation)
	_ads.initialized.connect(_on_initialized)
	_ads.ad_failed.connect(_on_ad_failed)
	return OK


## @api Silent info refresh once per configured launch; never opens a form at boot.
func start_session() -> Error:
	if not _configured():
		return ERR_UNCONFIGURED
	if _started:
		return ERR_ALREADY_IN_USE
	_started = true
	_step = Step.INFO
	_arm_legal()
	_consent.request_info()
	return OK


## @api Serialize campaign Continue with the completed slot, not the next slot.
func before_next_level(completed_slot: int) -> Error:
	if not _configured():
		return ERR_UNCONFIGURED
	if completed_slot < 1:
		return ERR_INVALID_PARAMETER
	if _slot > 0 or _presentation.busy():
		return ERR_BUSY
	_slot = completed_slot
	if not _started:
		start_session()
	_advance()
	return OK


## @api Explicit cancellation/watchdog seam. Retry unresolved steps next Continue.
func expire_operation() -> void:
	var legal_pending: bool = _step != Step.IDLE
	if legal_pending:
		_legal_timer.stop()
		_analytics_live = false
		_step = Step.IDLE
		_sdk_ready = false
	if is_instance_valid(_presentation):
		_presentation.expire()
	if legal_pending:
		_release()


func ads_ready() -> bool:
	return _configured() and _sdk_ready


func rewarded_state() -> StringName:
	return _presentation.rewarded_state() if ads_ready() else &"unavailable"


## @api Explicit opt-in. Only a validated bound Economy.grant can settle an earned reward.
func request_rewarded(placement: StringName, reward: Callable) -> Error:
	if is_instance_valid(_presentation) and _presentation.rewarded_state() == &"pending_reward":
		return _presentation.request_rewarded(placement, reward)
	if not ads_ready() or _slot > 0 or _step != Step.IDLE:
		return ERR_UNAVAILABLE
	var error: Error = _validate_placement(placement, reward)
	return _presentation.request_rewarded(placement, reward) if error == OK else error


func _validate_placement(placement: StringName, reward: Callable) -> Error:
	var keys: Dictionary = {
		&"hint": &"ads.rewarded.hint.enabled", &"double_reward": &"ads.rewarded.double.enabled"
	}
	if placement not in [&"hint", &"double_reward", &"shop_coins"]:
		return ERR_INVALID_PARAMETER
	if keys.has(placement) and not _config.get_bool(keys[placement]):
		return ERR_UNAVAILABLE
	if placement == &"shop_coins":
		if not _shop_available():
			return ERR_UNAVAILABLE
		if (
			not reward.is_valid()
			or (
				reward.get_bound_arguments()
				!= [&"rewarded_coins", {"coins": _config.get_int(&"economy.reward.rewarded_coins")}]
			)
		):
			return ERR_INVALID_PARAMETER
	return OK


func _local_day() -> String:
	var bias_seconds: int = int(Time.get_time_zone_from_system()["bias"]) * 60
	return (
		Time
		. get_datetime_string_from_unix_time(get_clock().unix_time_seconds() + bias_seconds)
		. left(10)
	)


func _shop_available() -> bool:
	var cap: Dictionary = _save.get_section(&"monetization")["shop_coins_ads"]
	var day: String = _local_day()
	if cap["date"] != null and day < str(cap["date"]):
		return false
	var used: int = int(cap["count"]) if cap["date"] == day else 0
	return used < _config.get_int(&"ads.rewarded.shop_coins.daily_cap")


func _reserve_shop_reward() -> Error:
	var section: Dictionary = _save.get_section(&"monetization")
	if _shop_reservation.is_empty():
		if not _shop_available():
			return ERR_UNAVAILABLE
		_shop_reservation = section["shop_coins_ads"].duplicate(true)
		_shop_reservation["count"] = (
			int(_shop_reservation["count"]) + 1 if _shop_reservation["date"] == _local_day() else 1
		)
		_shop_reservation["date"] = _local_day()
	section["shop_coins_ads"] = _shop_reservation.duplicate(true)
	var error: Error = _save.set_section(&"monetization", section)
	if error == OK:
		error = _save.flush()
	if error == OK:
		_shop_reservation.clear()
	return error


## @api T-0271 owns verified and durable grant/flush/finish transaction processing.
func purchase(_product_id: String) -> Error:
	return ERR_UNAVAILABLE


func restore_purchases() -> Error:
	return ERR_UNAVAILABLE


func process_unfinished_transactions() -> Error:
	return ERR_UNAVAILABLE


## @api Caller cannot override owned readiness, history, budget or entitlement.
func can_offer_interstitial(state: Dictionary) -> bool:
	if not _configured():
		return false
	if not state.get("completed_slot") is int or int(state["completed_slot"]) < 1:
		return false
	var owned: Dictionary = state.duplicate(true)
	owned["sdk_ready"] = _sdk_ready
	owned["ad_loaded"] = _presentation.interstitial_ready()
	owned["remove_forced_ads"] = _save.get_section(&"monetization")["remove_forced_ads"]
	owned["session_start_seconds"] = _session_start
	owned["prompts_used"] = _prompts
	var stored: Dictionary = _save.get_section(&"monetization")
	var slot: int = int(owned.get("completed_slot", 0))
	owned["last_interstitial_slot"] = _last_ad_slot
	if _last_ad_slot == -1 and stored["last_interstitial_time"] != null:
		owned["last_interstitial_slot"] = maxi(0, slot - _levels_since_ad)
	owned["last_interstitial_seconds"] = _last_ad_seconds
	if _last_ad_seconds == -1 and stored["last_interstitial_time"] != null:
		var elapsed: int = maxi(
			0, get_clock().unix_time_seconds() - int(stored["last_interstitial_time"])
		)
		owned["last_interstitial_seconds"] = maxi(0, get_clock().monotonic_msec() / 1000 - elapsed)
	owned["last_purchase_slot"] = (
		-1 if stored["last_purchase_slot"] == null else int(stored["last_purchase_slot"])
	)
	var values: Dictionary = {}
	for key: String in AdPolicy.KEYS:
		if not _config.has_key(StringName(key)):
			return false
		values[key] = _config.get_int(StringName(key))
	return (
		not _history_failed
		and AdPolicy.should_show_interstitial(owned, values, get_clock().monotonic_msec() / 1000)
	)


func _configured() -> bool:
	return is_instance_valid(_save) and is_instance_valid(_config) and is_instance_valid(_events)


func _advance() -> void:
	if _slot == 0 or _step != Step.IDLE:
		return
	if _slot < _config.get_int(&"consent.ump_after_slot"):
		_release()
	elif _ump == ConsentAdapter.State.UNKNOWN:
		_step = Step.INFO
		_arm_legal()
		_consent.request_info()
	elif _ump == ConsentAdapter.State.REQUIRED:
		_step = Step.FORM
		_arm_legal()
		_consent.show_form_if_required()
	elif (
		_ios and _att in [ConsentAdapter.AttStatus.UNKNOWN, ConsentAdapter.AttStatus.NOT_DETERMINED]
	):
		if _slot < _config.get_int(&"consent.att_after_slot"):
			_release()
		else:
			_step = Step.ATT
			_arm_legal()
			_consent.request_att()
	elif not _sdk_ready:
		_step = Step.INITIALIZING
		_arm_legal()
		_ads.initialize(_ump)
	else:
		_after_consent()


func _on_consent(state: ConsentAdapter.State) -> void:
	if _step not in [Step.INFO, Step.FORM]:
		return
	var was_form: bool = _step == Step.FORM
	_legal_timer.stop()
	_step = Step.IDLE
	_ump = state if state in ConsentAdapter.State.values() else ConsentAdapter.State.UNKNOWN
	if _ump == ConsentAdapter.State.UNKNOWN or (was_form and _ump == ConsentAdapter.State.REQUIRED):
		_release()
	else:
		_advance()


func _on_att(status: ConsentAdapter.AttStatus) -> void:
	if _step != Step.ATT:
		return
	_legal_timer.stop()
	_step = Step.IDLE
	_att = status
	if (
		status
		not in [
			ConsentAdapter.AttStatus.AUTHORIZED,
			ConsentAdapter.AttStatus.DENIED,
			ConsentAdapter.AttStatus.RESTRICTED
		]
	):
		_att = ConsentAdapter.AttStatus.UNKNOWN
		_release()
	else:
		_advance()


func _on_analytics(allowed: bool) -> void:
	if _configured() and _started and _analytics_live:
		_events.consent_changed.emit(allowed)


func _on_initialized() -> void:
	if _step != Step.INITIALIZING:
		return
	_step = Step.IDLE
	_legal_timer.stop()
	_sdk_ready = true
	_after_consent()


func _after_consent() -> void:
	if _slot == 0:
		return
	var visit: String = "%s:%d" % [_save.get_setting(&"language"), _slot]
	if visit == _last_evaluated:
		_release()
		return
	if not _last_visit.is_empty() and visit != _last_visit:
		_levels_since_ad = mini(_levels_since_ad + 1, ProgressSnapshot.MAX_SAFE_COUNT)
	_last_visit = visit
	_last_evaluated = visit
	if can_offer_interstitial({"context": "campaign_continue", "completed_slot": _slot}):
		_presentation.show_interstitial()
	else:
		if _slot >= _config.get_int(&"ads.interstitial.first_slot"):
			_presentation.prepare_interstitial()
		_release()


func _arm_legal() -> void:
	if _step in [Step.INFO, Step.FORM]:
		_analytics_live = true
	_legal_timer.start()


func _relay_audio_pause(paused: bool) -> void:
	audio_pause_requested.emit(paused)


func _on_interstitial_opened() -> void:
	_last_ad_slot = _slot
	_last_ad_seconds = get_clock().monotonic_msec() / 1000
	_levels_since_ad = 0
	_prompts += 1
	var section: Dictionary = _save.get_section(&"monetization")
	section["last_interstitial_time"] = get_clock().unix_time_seconds()
	section["levels_since_interstitial"] = 0
	var error: Error = _save.set_section(&"monetization", section)
	if error == OK:
		error = _save.flush()
	_history_failed = error != OK


func _on_ad_failed(_reason: String) -> void:
	if _step == Step.INITIALIZING:
		expire_operation()


func _release() -> void:
	if _slot == 0:
		return
	var completed: int = _slot
	_slot = 0
	continuation_ready.emit(completed)


func _disconnect() -> void:
	if is_instance_valid(_presentation):
		_presentation.free()
	if is_instance_valid(_legal_timer):
		_legal_timer.free()
	if _consent != null:
		_consent.consent_resolved.disconnect(_on_consent)
		_consent.att_resolved.disconnect(_on_att)
		_consent.analytics_resolved.disconnect(_on_analytics)
		_consent.operation_failed.disconnect(expire_operation)
	if _ads != null:
		_ads.initialized.disconnect(_on_initialized)
		_ads.ad_failed.disconnect(_on_ad_failed)


func _exit_tree() -> void:
	_disconnect()
