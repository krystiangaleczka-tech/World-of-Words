class_name AdsFake
extends AdsAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()


## @api Record initialize; tests emit inherited signals to deliver success/failure/pending.
func initialize(consent: ConsentAdapter.State) -> void:
	calls.record("initialize", [consent])


## @api Record load_rewarded; tests emit inherited signals to deliver success/failure/pending.
func load_rewarded() -> void:
	calls.record("load_rewarded", [])


## @api Record show_rewarded; tests emit inherited signals to deliver success/failure/pending.
func show_rewarded() -> void:
	calls.record("show_rewarded", [])


## @api Record load_interstitial; tests emit inherited signals to deliver success/failure/pending.
func load_interstitial() -> void:
	calls.record("load_interstitial", [])


## @api Record show_interstitial; tests emit inherited signals to deliver success/failure/pending.
func show_interstitial() -> void:
	calls.record("show_interstitial", [])
