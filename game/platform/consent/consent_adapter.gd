class_name ConsentAdapter
extends RefCounted
## @api consent adapter contract; signals report outcomes, never gameplay grants.

signal consent_resolved(state: State)
signal att_resolved(status: AttStatus)
## Explicit purpose-specific provider/legal decision; never inferred from UMP or ATT.
signal analytics_resolved(allowed: bool)
## Independent provider requirement; getter must already reflect the emitted value.
signal privacy_options_requirement_changed(requirement: PrivacyRequirement)
## Optional terminal for current privacy form only; OK does not imply consent.
signal privacy_options_completed(error: Error)
signal operation_failed

enum PrivacyRequirement { UNKNOWN, NOT_REQUIRED, REQUIRED }
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


## @api UNKNOWN fails closed; never infer this requirement from UMP, ATT or analytics.
func privacy_options_requirement() -> PrivacyRequirement:
	return PrivacyRequirement.UNKNOWN
