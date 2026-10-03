extends Control

var _output: Label
var _billing: BillingClient


func _ready() -> void:
	_output = Label.new()
	_output.position = Vector2(24, 80)
	_output.size = Vector2(672, 900)
	_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output.add_theme_font_size_override("font_size", 28)
	add_child(_output)
	_record("S1 diagnostic smoke test; matrix NOT PASSED")
	_record("Godot: " + Engine.get_version_info()["string"])
	_record("Package: com.mazen.worldofwordgame.spike")
	for singleton: String in [
		"PoingGodotAdMob",
		"PoingGodotAdMobConsentInformation",
		"PoingGodotAdMobRewardedAd",
		"PoingGodotAdMobInterstitialAd",
		"GodotGooglePlayBilling",
	]:
		_record("Native %s: %s" % [singleton, Engine.has_singleton(singleton)])
	_record("Ads remain uninitialized: UMP resources required")
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = BillingClient.new()
		add_child(_billing)
		_billing.connected.connect(func() -> void: _record("Billing connected (smoke only)"))
		_billing.connect_error.connect(_on_billing_error)
		_billing.start_connection()
	else:
		_record("Billing native singleton MISSING")


func _on_billing_error(code: int, message: String) -> void:
	_record("Billing connection error %d: %s" % [code, message])


func _record(message: String) -> void:
	print("S1: " + message)
	_output.text += message + "\n"


func _exit_tree() -> void:
	if is_instance_valid(_billing):
		_billing.end_connection()
