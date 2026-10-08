class_name SaveMigrations
extends RefCounted
## @api Ordered pure migration chain. The default v2 chain includes the built-in v1 migration.

var _target: int
var _steps: Dictionary[int, Callable] = {}


## Explicit targets are caller-owned chains, including custom future-version tests.
func _init(target: int = -1) -> void:
	_target = SaveSchema.VERSION if target == -1 else target
	if target == -1 and _target == 2:
		_steps[1] = MigrateV1ToV2.migrate


## @api Register migrate_vN_to_vN1; duplicate, invalid and out-of-range steps are rejected.
func register_step(from_version: int, migration: Callable) -> Error:
	if (
		from_version < 1
		or from_version >= _target
		or _steps.has(from_version)
		or not migration.is_valid()
	):
		return ERR_INVALID_PARAMETER
	_steps[from_version] = migration
	return OK


## @api Return a migrated deep copy, or {} for a missing/invalid step or future schema.
func upgrade(source: Dictionary) -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	var version: Variant = data.get("schema_version")
	if not (version is int or version is float) or not is_finite(float(version)):
		return {}
	if float(version) != floor(float(version)) or float(version) < 1 or float(version) > _target:
		return {}
	while int(version) < _target:
		if not _steps.has(int(version)):
			return {}
		var result: Variant = _steps[int(version)].call(data.duplicate(true))
		if not result is Dictionary or result.get("schema_version") != int(version) + 1:
			return {}
		data = result
		version = int(version) + 1
	return data
