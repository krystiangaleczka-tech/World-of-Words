# T-0339 — offline Settings credits data

The catalog preserves seven sections: current Godot licence, complete Godot
third-party copyright metadata, every Godot third-party licence text, Inter,
Lucide/Feather, synthesized P1 audio, and PL source attributions.

Engine metadata is read from the running engine, not copied from another version.
`godot-copyrights` is complete indented JSON; future T-0288 presentation can display
it verbatim. `godot-licenses` contains sorted licence names and full texts. All
other entries preserve the canonical legal notice verbatim. No translated titles
or player-facing UI are introduced here. Fresh arrays/dictionaries prevent caller
mutations from corrupting subsequent snapshots.

Audio and content notices are embedded in `.tres` metadata because raw Markdown
and extensionless NOTICE files are not selected by existing all_resources exports.
The generator's --check mode is covered by tools tests in make check and CI, so a
canonical NOTICE change requires regeneration. Existing font/icon resources are
reused without modifying their text or the generated theme.

## Validation

Preflight used clean main 52b009d; font/icon and release export prerequisites are
merged. Focused tests passed: 5 GUT tests / 66 assertions; 5 Python generator tests.
Full make check, fresh independent review, exact-head CI and downloaded Release
artifact verification are recorded in the task PR before merge.

Release inspection checks these source resources or their `.remap` targets:

- assets/fonts/font_license.tres
- assets/icons/icon_license.tres
- assets/audio/p1/audio_notice.tres
- content/source_notice.tres
- services/settings_credits.gd (compiled script/remap)

Canonical content notice includes SJP.PL CC BY attribution, version/hash and
modification statement; KWJP100/IPI PAN attribution, pin and modification statement;
full Morfeusz SGJP dictionary and engine BSD copyright/disclaimers. Audio notice
retains the placeholder provenance and CC0 statement. No raw corpora are added.

## Open gates

T-0288 still owns the visible licences screen and restore/privacy/browser/support
actions. No native SDK is activated by this task. Native provider activation and
final asset/source replacements must update the current catalog before release.
This work does not certify store/legal compliance or physical-device approval.
