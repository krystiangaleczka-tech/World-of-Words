class_name AdsAdapter
extends RefCounted
## @api ads adapter contract; signals report outcomes, never gameplay grants.

signal rewarded_loaded
signal reward_earned
signal ad_closed
signal ad_failed(reason: String)


## @api initialize: provider operation.
func initialize(_consent: ConsentAdapter.State) -> void:
	pass


## @api load_rewarded: provider operation.
func load_rewarded() -> void:
	pass


## @api show_rewarded: provider operation.
func show_rewarded() -> void:
	pass


## @api load_interstitial: provider operation.
func load_interstitial() -> void:
	pass


## @api show_interstitial: provider operation.
func show_interstitial() -> void:
	pass
