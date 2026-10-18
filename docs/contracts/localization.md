# Localization integrity

## Source contract (T-0351)

`tools/check_locale.py` reads every `game/locale/*.csv`, in sorted order, without
rewriting or importing files. `load_catalog(root)` returns sorted English keys
with exact PL/EN copy, or raises ValueError containing sorted path/physical-line
diagnostics. CLI defaults to its repository even when called from another cwd.
Existing tools pytest executes the actual repository guard in local checks/CI.

Every nonempty area has exactly `keys,pl,en`, three cells per nonblank record,
unique `area.screen.element` keys matching its filename and trimmed nonempty
translations. Quoted commas, Unicode, internal newline/tab are supported; malformed
UTF-8/CSV and other C0 controls fail. Neither English fallback nor key echo is
accepted as evidence of bilingual completeness by this source contract.

PL/EN must consume the same ordered Godot percent-format arguments: s,d,o,x,X,f,v,c
and int arguments for dynamic width/precision. Display widths may differ; argument
types/count/order may not. `%%` is literal; standalone numeric percentage labels
such as `100%` require no arguments. Within formatted copy use `%%` for a literal
percent. This guard checks integrity, not grammar, tone or plural semantics.

## Planned bounded T-0289 wave

T-0351 source integrity precedes T-0352 imported-resource parity and T-0353 static
key/shipped metadata references. Existing screen matrices remain visual evidence;
no geometry or copy changes are made here. Chris still approves Polish prose and
plural-neutral wording. Shipped campaign names/facts are reviewed only when actual
metadata exists; legacy virtual campaign placeholders do not certify a finished
travel catalog. EN translations do not activate an English content campaign.
