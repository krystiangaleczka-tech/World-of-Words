extends ServiceStub
## @api Unactivated consent contract; ad presentation and transactions belong to later tasks.

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


## @api No implicit provider operation; reconfiguration disconnects old adapters.
func configure(
	save: SAVE_SCRIPT,
	config: CONFIG_SCRIPT,
	events: EVENTS_SCRIPT,
	consent: ConsentAdapter,
	ads: AdsAdapter,
	ios: bool
) -> Error:
	if _slot > 0 or _step != Step.IDLE:
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
	_consent.request_info()
	return OK


## @api Serialize campaign Continue with the completed slot, not the next slot.
func before_next_level(completed_slot: int) -> Error:
	if not _configured():
		return ERR_UNCONFIGURED
	if completed_slot < 1:
		return ERR_INVALID_PARAMETER
	if _slot > 0:
		return ERR_BUSY
	_slot = completed_slot
	if not _started:
		start_session()
	_advance()
	return OK


## @api Explicit cancellation/watchdog seam. Retry unresolved steps next Continue.
func expire_operation() -> void:
	if _step == Step.IDLE:
		return
	_step = Step.IDLE
	_sdk_ready = false
	_release()


func ads_ready() -> bool:
	return _configured() and _sdk_ready


func rewarded_state() -> StringName:
	return &"unavailable"


## @api No callback/reward until T-0263 supplies presentation and durable settlement.
func request_rewarded(_placement: StringName, _reward: Callable) -> Error:
	return ERR_UNAVAILABLE


## @api T-0271 owns verified and durable grant/flush/finish transaction processing.
func purchase(_product_id: String) -> Error:
	return ERR_UNAVAILABLE


func restore_purchases() -> Error:
	return ERR_UNAVAILABLE


func process_unfinished_transactions() -> Error:
	return ERR_UNAVAILABLE


## @api Caller cannot override owned readiness/entitlement. No loaded ad in T-0261.
func can_offer_interstitial(state: Dictionary) -> bool:
	if not _configured():
		return false
	var owned: Dictionary = state.duplicate(true)
	owned["sdk_ready"] = _sdk_ready
	owned["ad_loaded"] = false
	owned["remove_forced_ads"] = _save.get_section(&"monetization")["remove_forced_ads"]
	var values: Dictionary = {}
	for key: String in AdPolicy.KEYS:
		if not _config.has_key(StringName(key)):
			return false
		values[key] = _config.get_int(StringName(key))
	return AdPolicy.should_show_interstitial(owned, values, get_clock().monotonic_msec() / 1000)


func _configured() -> bool:
	return is_instance_valid(_save) and is_instance_valid(_config) and is_instance_valid(_events)


func _advance() -> void:
	if _slot == 0 or _step != Step.IDLE:
		return
	if _slot < _config.get_int(&"consent.ump_after_slot"):
		_release()
	elif _ump == ConsentAdapter.State.UNKNOWN:
		_step = Step.INFO
		_consent.request_info()
	elif _ump == ConsentAdapter.State.REQUIRED:
		_step = Step.FORM
		_consent.show_form_if_required()
	elif (
		_ios and _att in [ConsentAdapter.AttStatus.UNKNOWN, ConsentAdapter.AttStatus.NOT_DETERMINED]
	):
		if _slot < _config.get_int(&"consent.att_after_slot"):
			_release()
		else:
			_step = Step.ATT
			_consent.request_att()
	elif not _sdk_ready:
		_step = Step.INITIALIZING
		_ads.initialize(_ump)
	else:
		_release()


func _on_consent(state: ConsentAdapter.State) -> void:
	if _step not in [Step.INFO, Step.FORM]:
		return
	var was_form: bool = _step == Step.FORM
	_step = Step.IDLE
	_ump = state if state in ConsentAdapter.State.values() else ConsentAdapter.State.UNKNOWN
	if _ump == ConsentAdapter.State.UNKNOWN or (was_form and _ump == ConsentAdapter.State.REQUIRED):
		_release()
	else:
		_advance()


func _on_att(status: ConsentAdapter.AttStatus) -> void:
	if _step != Step.ATT:
		return
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
	if _configured() and _started:
		_events.consent_changed.emit(allowed)


func _on_initialized() -> void:
	if _step != Step.INITIALIZING:
		return
	_step = Step.IDLE
	_sdk_ready = true
	_release()


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
