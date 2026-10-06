class_name ReviewFake
extends ReviewAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()


## @api Record request_review; tests emit inherited signals to deliver success/failure/pending.
func request_review() -> void:
	calls.record("request_review", [])
