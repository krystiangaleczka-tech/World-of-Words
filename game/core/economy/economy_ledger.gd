class_name EconomyLedger
extends RefCounted
## @api Pure mutable ledger. Services own journal, durability, eligibility and reward identities.

var _wallet: WalletSnapshot
var _rewards: RewardTable
var _bonus: int = 0
var _required: int = 0


## @api Atomic construction from owner wallet state and injected canonical config.
static func from_dict(source: Dictionary, config: Dictionary) -> EconomyLedger:
	var wallet: WalletSnapshot = WalletSnapshot.from_dict(
		{"coins": source.get("coins"), "items": source.get("items")}
	)
	var bonus: Variant = source.get("bonus_counter")
	var required: Variant = config.get("bonus.chest.words_required")
	var rewards: RewardTable = RewardTable.from_config(config)
	if wallet == null or rewards == null or not _saved_count(bonus):
		return null
	if not required is int or required < 1 or required > WalletSnapshot.MAX_SAFE_COUNT:
		return null
	var ledger: EconomyLedger = EconomyLedger.new()
	ledger._wallet = wallet
	ledger._rewards = rewards
	ledger._bonus = int(bonus)
	ledger._required = required
	return ledger


## @api Independent wallet/bonus serialization; service-owned journal/extensions are not replaced.
func snapshot() -> Dictionary:
	if _wallet == null:
		return {}
	var result: Dictionary = _wallet.snapshot()
	result["bonus_counter"] = _bonus
	return result


func can_afford(amounts: Dictionary) -> bool:
	return _wallet != null and _wallet.can_afford(amounts)


## @api Atomic explicit grant; invalid reason/request or safe overflow never changes wallet.
func grant(source: StringName, amounts: Dictionary) -> Error:
	if _wallet == null:
		return ERR_UNCONFIGURED
	if not _reason(source) or not WalletSnapshot.valid_amounts(amounts):
		return ERR_INVALID_PARAMETER
	var next: WalletSnapshot = _wallet.granted(amounts)
	if next == null:
		return ERR_INVALID_DATA
	_wallet = next
	return OK


## @api Atomic spend; false on invalid reason/request or insufficient funds.
func spend(sink: StringName, amounts: Dictionary) -> bool:
	if _wallet == null or not _reason(sink):
		return false
	var next: WalletSnapshot = _wallet.spent(amounts)
	if next == null:
		return false
	_wallet = next
	return true


## @api Configured coin cost; tool item-first consumption belongs to the future owning service.
func price(tool: StringName) -> Dictionary:
	return _rewards.price(tool) if _rewards != null else {}


## @api Known configured reward; double applies only to the base level reward.
func grant_reward(source: StringName, double_level: bool = false) -> Error:
	if _rewards == null:
		return ERR_UNCONFIGURED
	var amounts: Dictionary = _rewards.reward(source, double_level)
	if amounts.is_empty():
		return ERR_INVALID_PARAMETER
	for value: int in amounts.values():
		if value > 0:
			return grant(source, amounts)
	return OK


## @api Caller supplies new eligible BONUS count; accumulate only, never pay mid-level.
func add_bonus(words: int, enabled: bool = true) -> Error:
	if _wallet == null:
		return ERR_UNCONFIGURED
	if words < 1 or words > WalletSnapshot.MAX_SAFE_COUNT:
		return ERR_INVALID_PARAMETER
	if not enabled:
		return OK
	if _bonus > WalletSnapshot.MAX_SAFE_COUNT - words:
		return ERR_INVALID_DATA
	_bonus += words
	return OK


## @api Explicit completion-boundary settlement, repeat-safe within this state.
func redeem_bonus_chests() -> Dictionary:
	if _wallet == null:
		return {}
	@warning_ignore("integer_division")
	var chests: int = _bonus / _required
	if chests == 0:
		return {"chests": 0, "reward": {}}
	var payout: int = _rewards.reward(&"bonus_chest")["coins"]
	@warning_ignore("integer_division")
	if payout > WalletSnapshot.MAX_SAFE_COUNT / chests:
		return {}
	var coins: int = payout * chests
	var next: WalletSnapshot = _wallet.granted({"coins": coins}) if coins > 0 else _wallet
	if next == null:
		return {}
	_wallet = next
	_bonus %= _required
	return {"chests": chests, "reward": {"coins": coins}}


static func _reason(reason: StringName) -> bool:
	var value: String = str(reason)
	return not value.is_empty() and value.strip_edges() == value


static func _saved_count(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= 0
		and value <= WalletSnapshot.MAX_SAFE_COUNT
		and floorf(float(value)) == float(value)
	)
