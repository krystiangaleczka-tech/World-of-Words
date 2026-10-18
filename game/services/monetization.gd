# gdlint: disable=max-public-methods
# The existing service facade also owns the explicit restore result API.
extends ServiceStub
## @api Unactivated consent, ads and explicit verified IAP settlement.

signal privacy_changed
signal restore_changed
signal shop_changed
signal continuation_ready(completed_slot: int)
signal audio_pause_requested(paused: bool)
signal purchase_state_changed(product_id: String, state: StringName, error: Error)

enum Step { IDLE, INFO, FORM, ATT, INITIALIZING, PRIVACY }

const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")
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
var _analytics_decision: int = -1
var _reported_consent: String = ""
var _shop_reservation: Dictionary = {}
var _iap_flow: IapFlow
var _shop_economy: ECONOMY_SCRIPT
var _shop_reward: Callable
var _privacy_state: StringName = &"idle"
var _privacy_error: Error = OK
var _privacy_revision: int = 0
var _privacy_connected: bool = false
var _privacy_notifying: bool = false
var _privacy_dispatch: bool = false


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
		_privacy_blocked()
		or _iap_binding_busy()
		or _slot > 0
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
	_analytics_decision = -1
	_reported_consent = ""
	_privacy_state = &"idle"
	_privacy_error = OK
	_levels_since_ad = int(_save.get_section(&"monetization")["levels_since_interstitial"])
	_presentation = AdPresentation.new()
	add_child(_presentation)
	_presentation.configure(_ads, _reserve_shop_reward, _save)
	_presentation.telemetry.connect(_telemetry)
	_presentation.changed.connect(_emit_shop_changed)
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
	_consent.operation_failed.connect(_on_legal_failed)
	_consent.privacy_options_completed.connect(_on_privacy_completed)
	_consent.privacy_options_requirement_changed.connect(_on_privacy_requirement)
	_privacy_connected = true
	_ads.initialized.connect(_on_initialized)
	_ads.ad_failed.connect(_on_ad_failed)
	_events.economy_changed.connect(_on_shop_economy)
	_publish_privacy()
	return OK


## @api Silent info refresh once per configured launch; never opens a form at boot.
func start_session() -> Error:
	if _privacy_blocked():
		return ERR_BUSY
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
	if _privacy_blocked():
		return ERR_BUSY
	if not _configured():
		return ERR_UNCONFIGURED
	if completed_slot < 1:
		return ERR_INVALID_PARAMETER
	if (
		_slot > 0
		or _presentation.busy()
		or (is_instance_valid(_iap_flow) and _iap_flow.presenting())
	):
		return ERR_BUSY
	_slot = completed_slot
	if not _started:
		start_session()
	_advance()
	return OK


## @api Explicit cancellation/watchdog seam. Retry unresolved steps next Continue.
func expire_operation() -> void:
	if _step == Step.PRIVACY:
		expire_privacy_options()
		return
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


## @api Exact read-only certification before a paid-tool screen uses this provider.
func matches_tool_owners(save: Node, economy: Node, config: Node) -> bool:
	return (
		_configured()
		and _save == save
		and _config == config
		and economy is ECONOMY_SCRIPT
		and economy.atomic_save_matches(save)
		and economy.tool_config_matches(config)
		and (_shop_economy == null or _shop_economy == economy)
	)


func ads_ready() -> bool:
	return _configured() and _sdk_ready


func rewarded_state() -> StringName:
	return _presentation.rewarded_state() if ads_ready() else &"unavailable"


## @api Explicit opt-in. Only a validated bound Economy.grant can settle an earned reward.
func request_rewarded(placement: StringName, reward: Callable) -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	if is_instance_valid(_presentation) and _presentation.rewarded_state() == &"pending_reward":
		var result: Error = _presentation.request_rewarded(placement, reward)
		_emit_shop_changed()
		return result
	if is_instance_valid(_iap_flow) and _iap_flow.presenting():
		return ERR_BUSY
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
	var bias_seconds: int = get_clock().time_zone_bias_minutes() * 60
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


## @api Explicit same-Save binding; no provider command or boot activation.
func configure_iap(economy: Node, adapter: IapAdapter) -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	if _iap_binding_busy() or (is_instance_valid(_presentation) and _presentation.busy()):
		return ERR_BUSY
	if not _configured() or not economy is ECONOMY_SCRIPT or adapter == null:
		return ERR_UNCONFIGURED
	if (
		not economy.is_ready()
		or not economy.atomic_save_matches(_save)
		or economy.atomic_has_pending()
	):
		return ERR_UNCONFIGURED
	if is_instance_valid(_iap_flow):
		_iap_flow.free()
	_iap_flow = IapFlow.new()
	add_child(_iap_flow)
	_iap_flow.configure(_save, economy, adapter)
	_iap_flow.telemetry.connect(_telemetry)
	_iap_flow.state_changed.connect(_on_purchase_state)
	_iap_flow.changed.connect(_emit_shop_changed)
	_iap_flow.restore_changed.connect(_on_restore_changed)
	_shop_economy = economy
	_shop_reward = Callable()
	_emit_shop_changed()
	return OK


## @api Presentation data only; copied prices and actual owners determine availability.
func shop_snapshot() -> Dictionary:
	if (
		not _configured()
		or not is_instance_valid(_shop_economy)
		or not _shop_economy.is_ready()
		or not _shop_economy.atomic_save_matches(_save)
		or not is_instance_valid(_iap_flow)
	):
		return {}
	var catalog: Dictionary = _iap_flow.catalog_snapshot()
	var owned: bool = _save.committed_view().sections.monetization.remove_forced_ads
	var products: Dictionary = {}
	for id: String in IapFlow.PRODUCTS:
		var product: Dictionary = catalog.products.get(id, {}).duplicate(true)
		product["state"] = _iap_flow.product_state(id)
		products[id] = product
	var reward: StringName = _presentation.rewarded_state()
	if reward == &"pending_reward" and not _presentation.can_retry(&"shop_coins", _shop_reward):
		reward = &"unavailable"
	elif reward != &"pending_reward":
		reward = rewarded_state()
	return {
		"coins": _shop_economy.snapshot().coins,
		"owned": owned,
		"products": products,
		"catalog_state": catalog.state,
		"purchase_state": _iap_flow.state(),
		"failure_revision": _iap_flow.failure_revision,
		"reward_state": reward,
		"reward_pending": _presentation.rewarded_state() == &"pending_reward",
		"ads_ready": ads_ready(),
		"capped": not _shop_available(),
		"coin_amount": _config.get_int(&"iap.coins_s.amount"),
		"reward_amount": _config.get_int(&"economy.reward.rewarded_coins")
	}


func begin_shop_visit() -> void:
	if is_instance_valid(_presentation):
		_presentation.begin_shop_visit()
		_emit_shop_changed()


func request_products() -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	return _iap_flow.query_products() if is_instance_valid(_iap_flow) else ERR_UNAVAILABLE


func request_shop_reward() -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	if shop_snapshot().is_empty():
		return ERR_UNCONFIGURED
	if _presentation.rewarded_state() != &"pending_reward":
		_shop_reward = _shop_economy.grant.bind(
			&"rewarded_coins", {"coins": _config.get_int(&"economy.reward.rewarded_coins")}
		)
	var error: Error = request_rewarded(&"shop_coins", _shop_reward)
	_emit_shop_changed()
	return error


func _on_shop_economy(
	_operation: StringName, _reason: StringName, _amounts: Dictionary, _wallet: Dictionary
) -> void:
	_emit_shop_changed()


func _emit_shop_changed() -> void:
	shop_changed.emit()


func purchase_state() -> StringName:
	return _iap_flow.state() if is_instance_valid(_iap_flow) else &"unavailable"


func purchase(product_id: String) -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	if not is_instance_valid(_iap_flow):
		return ERR_UNAVAILABLE
	if _slot > 0 or _step != Step.IDLE or _presentation.busy():
		return ERR_BUSY
	return _iap_flow.purchase(product_id)


func restore_purchases() -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	return _iap_flow.recover(true) if is_instance_valid(_iap_flow) else ERR_UNAVAILABLE


func process_unfinished_transactions() -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	return _iap_flow.recover() if is_instance_valid(_iap_flow) else ERR_UNAVAILABLE


func _on_purchase_state(product: String, state: StringName, error: Error) -> void:
	purchase_state_changed.emit(product, state, error)


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
	if _step == Step.PRIVACY:
		_ump = state if state in ConsentAdapter.State.values() else ConsentAdapter.State.UNKNOWN
		_report_consent()
		return
	if _step not in [Step.INFO, Step.FORM]:
		return
	var was_form: bool = _step == Step.FORM
	_legal_timer.stop()
	_step = Step.IDLE
	_ump = state if state in ConsentAdapter.State.values() else ConsentAdapter.State.UNKNOWN
	_report_consent()
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
		_telemetry(&"att_result", {"status": ConsentAdapter.AttStatus.keys()[status].to_lower()})
		_advance()


func _on_analytics(allowed: bool) -> void:
	if _configured() and (_started or _privacy_state != &"idle") and _analytics_live:
		_analytics_decision = 1 if allowed else 0
		_events.consent_changed.emit(allowed)
		_report_consent()


func _on_initialized() -> void:
	if _step != Step.INITIALIZING:
		return
	_step = Step.IDLE
	_legal_timer.stop()
	_sdk_ready = true
	_after_consent()
	_emit_shop_changed()


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
	if _step in [Step.INFO, Step.FORM, Step.PRIVACY]:
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
	_privacy_connected = false
	if is_instance_valid(_events) and _events.economy_changed.is_connected(_on_shop_economy):
		_events.economy_changed.disconnect(_on_shop_economy)
	_shop_economy = null
	_shop_reward = Callable()
	if is_instance_valid(_iap_flow):
		_iap_flow.free()
	if is_instance_valid(_presentation):
		_presentation.free()
	if is_instance_valid(_legal_timer):
		_legal_timer.free()
	if _consent != null:
		if _consent.consent_resolved.is_connected(_on_consent):
			_consent.consent_resolved.disconnect(_on_consent)
		if _consent.att_resolved.is_connected(_on_att):
			_consent.att_resolved.disconnect(_on_att)
		if _consent.analytics_resolved.is_connected(_on_analytics):
			_consent.analytics_resolved.disconnect(_on_analytics)
		if _consent.operation_failed.is_connected(_on_legal_failed):
			_consent.operation_failed.disconnect(_on_legal_failed)
		if _consent.privacy_options_completed.is_connected(_on_privacy_completed):
			_consent.privacy_options_completed.disconnect(_on_privacy_completed)
		if _consent.privacy_options_requirement_changed.is_connected(_on_privacy_requirement):
			_consent.privacy_options_requirement_changed.disconnect(_on_privacy_requirement)
	if _ads != null:
		if _ads.initialized.is_connected(_on_initialized):
			_ads.initialized.disconnect(_on_initialized)
		if _ads.ad_failed.is_connected(_on_ad_failed):
			_ads.ad_failed.disconnect(_on_ad_failed)


func _exit_tree() -> void:
	if _step == Step.PRIVACY:
		_step = Step.IDLE
		_privacy_state = &"unknown"
		_privacy_error = ERR_UNAVAILABLE
	_analytics_live = false
	_disconnect()


func _report_consent() -> void:
	if (
		_analytics_decision < 0
		or (
			_ump
			not in [
				ConsentAdapter.State.REQUIRED,
				ConsentAdapter.State.NOT_REQUIRED,
				ConsentAdapter.State.OBTAINED
			]
		)
	):
		return
	var status: String = ConsentAdapter.State.keys()[_ump].to_lower()
	var signature: String = "%s:%d" % [status, _analytics_decision]
	if signature == _reported_consent:
		return
	_reported_consent = signature
	_telemetry(
		&"consent_result",
		{
			"analytics_allowed": _analytics_decision == 1,
			"ads_allowed":
			_ump in [ConsentAdapter.State.NOT_REQUIRED, ConsentAdapter.State.OBTAINED],
			"status": status
		}
	)


func _telemetry(name: StringName, params: Dictionary) -> void:
	if is_instance_valid(_events):
		_events.p2_analytics.emit(name, params.duplicate(true))


## @api View observation only; never authorizes or starts an ad/store operation.
func observe_shop_opened(origin: StringName = &"unknown") -> void:
	_telemetry(&"shop_opened", {"origin": "level" if origin == &"level" else "unknown"})


func observe_rewarded_offer(placement: StringName) -> void:
	if placement in [&"hint", &"double_reward", &"shop_coins"]:
		_telemetry(&"ad_offer_shown", {"placement": str(placement), "ad_format": "rewarded"})


func _iap_binding_busy() -> bool:
	return (
		is_instance_valid(_iap_flow)
		and (_iap_flow.busy() or _iap_flow.restore_snapshot().state in [&"requested", &"settling"])
	)


func _on_restore_changed() -> void:
	restore_changed.emit()


## @api Explicit restore result; UI must not consume analytics as application state.
func restore_snapshot() -> Dictionary:
	if is_instance_valid(_iap_flow):
		return _iap_flow.restore_snapshot()
	return {"state": &"unavailable", "restored_count": -1, "error": ERR_UNAVAILABLE, "revision": 0}


func retry_restore_settlement() -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	return _iap_flow.retry_restore_settlement() if is_instance_valid(_iap_flow) else ERR_UNAVAILABLE


func expire_restore() -> void:
	if is_instance_valid(_iap_flow):
		_iap_flow.expire_restore()


## @api Settings must bind the actual loaded profile and a live service.
func restore_owner_matches(save: Node) -> bool:
	return (
		is_inside_tree()
		and is_instance_valid(save)
		and save == _save
		and _save.is_loaded()
		and _configured()
		and is_instance_valid(_iap_flow)
	)


## @api Live connected owner proof, independent of an IAP binding.
func privacy_owner_matches(save: Node) -> bool:
	return (
		is_inside_tree()
		and _privacy_connected
		and _configured()
		and is_instance_valid(save)
		and save == _save
		and _save.is_loaded()
	)


## @api Fresh application state; requirement is never inferred from consent or ATT.
func privacy_snapshot() -> Dictionary:
	var live: bool = privacy_owner_matches(_save)
	var requirement: int = (
		_consent.privacy_options_requirement()
		if live
		else ConsentAdapter.PrivacyRequirement.UNKNOWN
	)
	var names: Array[StringName] = [&"unknown", &"not_required", &"required"]
	if requirement < 0 or requirement >= names.size():
		requirement = ConsentAdapter.PrivacyRequirement.UNKNOWN
	return {
		"requirement": names[requirement],
		"available": live and requirement == ConsentAdapter.PrivacyRequirement.REQUIRED,
		"state": _privacy_state if live else &"unavailable",
		"error": _privacy_error if live else ERR_UNAVAILABLE,
		"revision": _privacy_revision
	}


## @api Explicit acceptance only. Provider terminal evidence reports form completion.
func request_privacy_options() -> Error:
	if _privacy_blocked():
		return ERR_BUSY
	if not privacy_owner_matches(_save):
		return ERR_UNCONFIGURED
	if _step != Step.IDLE or _slot > 0 or _presentation.busy() or _iap_binding_busy():
		return ERR_BUSY
	if not privacy_snapshot().available:
		return ERR_UNAVAILABLE
	_privacy_dispatch = true
	_step = Step.PRIVACY
	_privacy_state = &"requested"
	_privacy_error = OK
	_sdk_ready = false
	_arm_legal()
	_publish_privacy()
	if _step == Step.PRIVACY:
		_consent.show_privacy_options()
	_privacy_dispatch = false
	return OK


## @api Only privacy wait is expired; no provider or competing flow is started.
func expire_privacy_options() -> void:
	_finish_privacy(&"unknown", ERR_TIMEOUT)


func _privacy_blocked() -> bool:
	return _step == Step.PRIVACY or _privacy_notifying or _privacy_dispatch


func _publish_privacy() -> void:
	_privacy_revision += 1
	var previous: bool = _privacy_notifying
	_privacy_notifying = true
	privacy_changed.emit()
	_emit_shop_changed()
	_privacy_notifying = previous


func _on_privacy_requirement(_requirement: ConsentAdapter.PrivacyRequirement) -> void:
	_publish_privacy()


func _on_privacy_completed(error: Error) -> void:
	_finish_privacy(&"completed" if error == OK else &"failed", error)


func _finish_privacy(state: StringName, error: Error) -> void:
	if _step != Step.PRIVACY:
		return
	_legal_timer.stop()
	_step = Step.IDLE
	_privacy_state = state
	_privacy_error = error
	if error != OK:
		_analytics_live = false
	_publish_privacy()


func _on_legal_failed() -> void:
	if _step != Step.PRIVACY:
		expire_operation()
