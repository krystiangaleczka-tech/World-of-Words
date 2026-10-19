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

## Imported-resource proof (T-0352)

`test_locale_parity.gd` enumerates every actual CSV cell and independently loads
its PL/EN Translation resource with cache ignore. Resource locale and exact
get_message value must match source, so server fallback cannot hide a missing or
wrong-language import. The registered catalog is separately checked over repeated
PL/EN/pl_PL/en_US cycles and idempotent register calls. Test restores locale and
pseudolocalization, and releases only its own registrations.

All current formatted messages render source/import with count boundaries1/2/5/21
and non-ASCII string arguments. This proves engine compatibility, not grammatical
plural neutrality. Controlled two-language user resources cover independent
registrations, outside owners, final release and corrupt-later-resource rollback
followed by explicit repaired retry. This is CI/runtime-resource evidence; no new
mobile screen-reader, visual, editorial or English-content claim is made.

## Bounded static references and travel metadata (T-0353)

`tools/check_locale_references.py` parses production GDScript in features/ui/services
using the existing AST. It checks literal tr/TranslationServer.translate calls,
closed UI *_key fields and key-shaped literals rooted in existing locale areas
(including constant maps). Empty optional fields are allowed. Scenes reuse existing
text guards and validate literal UI key fields. Comments/non-key identifiers are
ignored. Unknown static keys and unreadable/malformed inputs fail with path/line
errors. JSON output is deterministic and read only; tools pytest audits actual
current sources. Historical docs/qa/T-0353 evidence is not a regeneration gate.

Literal dynamic prefixes/templates are reported separately, without executing or
fully resolving arbitrary expressions. This bounded guard is not complete dataflow
analysis. Concrete dynamic states still need service/screen tests and review.

Every shipped language manifest is checked for copy references: legacy manifests
explicitly report no named travel copy. Grouped named metadata needs bilingual
region/location name keys. Landmark entries retain the existing slot/landmark
record shape and boolean flag, without invented names or numeric range validation;
derived location.<id>.fact either exists or is reported
pending, matching existing Postcard pending-copy behavior. No content schema,
partition/hash/artwork validation is replaced or changed. Current legacy campaign
does not certify named locations/facts. Source/import/reference integrity does not
close Chris's wording/plural/native or future travel-content review gates.
