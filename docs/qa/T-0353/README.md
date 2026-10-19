# T-0353 localization reference audit

Historical source evidence captured on main13323de, without UI/code/content edits:
347 bilingual keys,372 static references,22 literal dynamic prefixes/templates,
one legacy shipped campaign,zero named locations,zero static-reference errors.
`audit.json` lists exact source lines for review; it is a historical snapshot,
not a generated artifact every later feature task must rewrite.

Reproduce current audit from any cwd using the repository venv interpreter:
`uv run python tools/check_locale_references.py --json`.
The actual-repository tools test always checks the current source, not this snapshot.

Dynamic expressions are not fully resolved or certified by the static guard.
Existing service/screen tests exercise their concrete states. For editorial review,
read the corresponding `game/locale/<area>.csv` and current screen evidence. Chris
still approves PL wording, tone, plural neutrality and physical-device readability.
T-0352 checks exact imported PL/EN copy and formatting with1/2/5/21.

The current65-slot PL manifest has no named regions/locations. Legacy fallback
is reported explicitly and does not approve or invent travel names/facts. Future
named metadata must reference bilingual names. Missing optional facts are listed
as pending, matching current Postcard fallback. This is not a content schema/hash/
slot/artwork validator, an EN campaign activation or final T-0289 human sign-off.
