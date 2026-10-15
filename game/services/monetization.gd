extends ServiceStub
## @api Consent sequencing, ads, Remove Forced Ads entitlement and IAP entry points (T-0261).
## Every method is an inert fail-closed stub until T-0263 (consent, ads) and T-0271 (IAP).

## @api After an OK before_next_level: the caller loads the next level now; steps ran in order.
signal next_level_cleared(slot: int, steps: PackedStringArray)
## @api Exactly once per accepted offer: earned, closed_early, unavailable or failed.
signal rewarded_finished(placement: StringName, offer_id: int, outcome: StringName)
## @api True before a full-screen ad or consent form, false after it resolves; always paired.
signal ad_presentation_changed(active: bool)
## @api Published only after durable success of the purchase flow.
signal purchase_updated(product_id: StringName, state: StringName)

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")
const PLATFORM_SCRIPT: Script = preload("res://platform/platform.gd")
const PLACEMENTS: Array[StringName] = [&"hint", &"double", &"shop_coins"]
const PRODUCTS: Array[StringName] = [&"nc.remove_forced_ads.v1", &"c.coins_s.v1"]

var _save: SAVE_SCRIPT
var _config: CONFIG_SCRIPT
var _events: EVENTS_SCRIPT
var _economy: ECONOMY_SCRIPT
var _progress: PROGRESS_SCRIPT
var _platform: PLATFORM_SCRIPT
var _ios: bool = false


## @api Inject owners and the adapter container without I/O, adapter calls or signals.
func configure(
	save: SAVE_SCRIPT,
	config: CONFIG_SCRIPT,
	events: EVENTS_SCRIPT,
	economy: ECONOMY_SCRIPT,
	progress: PROGRESS_SCRIPT,
	platform: PLATFORM_SCRIPT,
	ios: bool
) -> void:
	_save = save
	_config = config
	_events = events
	_economy = economy
	_progress = progress
	_platform = platform
	_ios = ios


## @api Stub: never ready until T-0263.
func is_ready() -> bool:
	return false


## @api Silent consent refresh and unfinished transactions at boot; never shows a form.
func start_session() -> Error:
	return ERR_UNCONFIGURED


## @api Independent copy: {ump: StringName, att: StringName, ads_initialized: bool}.
func consent_state() -> Dictionary:
	return {"ump": &"unknown", "att": &"unknown", "ads_initialized": false}


## @api True only when UMP reports the privacy options form as required.
func privacy_options_available() -> bool:
	return false


## @api Opens the UMP privacy options form from Settings.
func show_privacy_options() -> Error:
	return ERR_UNCONFIGURED


## @api Non-OK: no signal follows and the caller proceeds at once. OK: one next_level_cleared.
func before_next_level(_slot: int) -> Error:
	return ERR_UNCONFIGURED


## @api Whether an offer for a known placement can start now; never true while busy.
func rewarded_available(_placement: StringName) -> bool:
	return false


## @api Positive offer id when accepted, 0 when rejected.
func show_rewarded(_placement: StringName) -> int:
	return 0


## @api Committed entitlement; never cleared locally once granted.
func has_remove_forced_ads() -> bool:
	return false


## @api Accepts only PRODUCTS; grant, durable flush and finish happen in that order.
func purchase(_product_id: StringName) -> Error:
	return ERR_UNCONFIGURED


## @api Restores non-consumables only.
func restore_purchases() -> Error:
	return ERR_UNCONFIGURED
