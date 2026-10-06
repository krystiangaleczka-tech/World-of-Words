class_name ConsentFake
extends ConsentAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()


## @api Record request_info; tests emit inherited signals to deliver success/failure/pending.
func request_info() -> void:
	calls.record("request_info", [])


## @api Record show_form_if_required; tests explicitly emit outcome signals.
func show_form_if_required() -> void:
	calls.record("show_form_if_required", [])


## @api Record request_att; tests emit inherited signals to deliver success/failure/pending.
func request_att() -> void:
	calls.record("request_att", [])


## @api Record show_privacy_options; tests explicitly emit outcome signals.
func show_privacy_options() -> void:
	calls.record("show_privacy_options", [])
