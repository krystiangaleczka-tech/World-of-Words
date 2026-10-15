class_name AdPolicy
extends RefCounted
## @api Pure policy: no autoload, clock, adapter or persistent state.

const KEYS: Array[String] = [
	"ads.interstitial.first_slot",
	"ads.interstitial.min_levels_between",
	"ads.interstitial.min_seconds_between",
	"ads.interstitial.session_grace_seconds",
	"ads.interstitial.purchase_grace_levels",
	"onboarding.max_prompts_per_session",
]
const EXEMPT: Array[StringName] = [&"consent", &"att", &"coach_mark", &"explicit_action"]
const AUTOMATIC: Array[StringName] = [&"interstitial", &"offer", &"rating", &"notice"]


## @api Unknown classifications fail closed; opt-in actions and legal flows are exempt.
static func can_show_prompt(kind: StringName, used: int, config: Dictionary) -> bool:
	if kind in EXEMPT:
		return true
	if kind not in AUTOMATIC or not config.get("onboarding.max_prompts_per_session") is int:
		return false
	var limit: int = config["onboarding.max_prompts_per_session"]
	return limit >= 0 and used >= 0 and used < limit


## @api Count only a successfully displayed automatic prompt.
static func next_prompt_count(kind: StringName, used: int, config: Dictionary) -> int:
	return used + 1 if kind in AUTOMATIC and can_show_prompt(kind, used, config) else used


## @api State fields: context, sdk_ready, ad_loaded, remove_forced_ads,
## completed_slot, last_interstitial_slot, last_interstitial_seconds,
## session_start_seconds, last_purchase_slot, prompts_used.
## Last event sentinel -1 means no event yet.
static func should_show_interstitial(state: Dictionary, config: Dictionary, now: int) -> bool:
	for key: String in KEYS:
		if not config.get(key) is int or config[key] < 0:
			return false
	if (
		state.get("context") != "campaign_continue"
		or state.get("sdk_ready") != true
		or state.get("ad_loaded") != true
		or state.get("remove_forced_ads") != false
		or not can_show_prompt(&"interstitial", state.get("prompts_used", -1), config)
	):
		return false
	for key: String in [
		"completed_slot", "last_interstitial_slot", "last_interstitial_seconds",
		"session_start_seconds", "last_purchase_slot"
	]:
		if not state.get(key) is int:
			return false
	var slot: int = state["completed_slot"]
	var prev_slot: int = state["last_interstitial_slot"]
	var prev_time: int = state["last_interstitial_seconds"]
	var session: int = state["session_start_seconds"]
	var purchase: int = state["last_purchase_slot"]
	if (
		slot < config["ads.interstitial.first_slot"]
		or slot < 1 or now < 0 or session < 0 or session > now
		or prev_slot < -1 or prev_time < -1 or purchase < -1
		or prev_slot > slot or purchase > slot or prev_time > now
	):
		return false
	if now - session < config["ads.interstitial.session_grace_seconds"]:
		return false
	if prev_slot >= 0 and slot - prev_slot < config["ads.interstitial.min_levels_between"]:
		return false
	if prev_time >= 0 and now - prev_time < config["ads.interstitial.min_seconds_between"]:
		return false
	if purchase >= 0 and slot - purchase < config["ads.interstitial.purchase_grace_levels"]:
		return false
	return true
