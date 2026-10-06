class_name ConsentAdapter
extends RefCounted
## @api consent adapter contract; signals report outcomes, never gameplay grants.

signal consent_resolved(state: State)
signal att_resolved(status: AttStatus)

enum State { UNKNOWN, REQUIRED, NOT_REQUIRED, OBTAINED }
enum AttStatus { UNKNOWN, NOT_DETERMINED, RESTRICTED, DENIED, AUTHORIZED }


## @api request_info: provider operation.
func request_info() -> void:
	pass


## @api show_form_if_required: provider operation.
func show_form_if_required() -> void:
	pass


## @api request_att: provider operation.
func request_att() -> void:
	pass


## @api show_privacy_options: provider operation.
func show_privacy_options() -> void:
	pass
