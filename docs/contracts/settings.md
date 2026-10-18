# Save-owned settings (T-0284)

ARCHITECTURE.md assigns `settings` to Save. There is no Settings autoload, new
save field, schema version or analytics event. The closed keys and types remain:

| Key | Value |
| --- | --- |
| sfx_volume, music_volume | finite float, 0..1 |
| haptics_enabled, reduced_motion, high_contrast | bool |
| text_scale | int 0/1/2 = 100/115/130 percent |
| language | supported shipped content language ID; currently pl |

`Save.get_setting(key: StringName) -> Variant` reads the owner's working value;
unknown names return null. `Save.set_setting(key, value) -> Error` validates the
whole candidate, persists immediately and emits `setting_changed(key)` only after
a successful flush. Invalid values do not mutate. Active atomic work returns
ERR_BUSY. Failed writes remain dirty: UI reads `Save.committed_view().sections.settings`
for selected/applied state, shows a translated error and explicitly retries the
same pending value. It never presents an uncommitted setting as active. An unrelated
successful flush can finish pending settings and emit their notification once.

## Composition and intent (T-0285)

`SettingsScreen extends ScreenScaffold`; `configure(save: Node) -> Error` validates
a loaded Save before mount. The screen is unmapped in boot/Nav. Catalog TopBar,
ListRow, CatalogSlider, Toggle, Sheet/TextButton, StatePanel and Toast are the only
controls. Existing ListRow owns nested input suppression; the screen owns detached
trailing controls and Sheet content lifetimes. Screen signals:
`back_requested`, `setting_requested(key: StringName, value: Variant)` and
`action_requested(action: StringName)`. Initial screen task sends intent only.
No Save mutation, browser/mail, platform/provider or navigation call occurs there.
Sound/display/language/purchases/privacy/about sections follow DESIGN.md#settings.
Rows awaiting T-0288 send named intent; consent-specific Privacy Options is hidden
unless an injected availability flag says required. Owned removal has a passive
Owned value and no purchase action. Restore result is never fabricated.

## Persistence and apply (T-0286)

`SettingsRuntime extends Node`, explicitly caller-owned under `game/services/`.
`configure(save: Node, root: Control) -> Error` validates the loaded owner and a
real theme root; `set_value(key: StringName, value: Variant) -> Error` and
`retry() -> Error` own one pending setting. `snapshot() -> Dictionary` returns
copied committed settings; `changed` and `write_failed(error: Error)` report actual
state. Runtime denies language writes (T-0287 owns coherent content switching).
It serializes/rejects reentrant replacements, retries the exact failed value,
and handles another successful Save flush resolving that same candidate.

Only committed notifications apply `Tokens.reduced_motion` and the root's exact
pre-generated theme (default/HC x100/115/130). Disconnect/reconnect once on lifecycle
changes; kill no foreign tween. No generated theme edits or new theme variants.
Existing Audio owns SFX volume; `Audio.bind_music(player: AudioStreamPlayer) -> Error`
adds an explicit caller-owned music volume/pause hook without starting a track.
HapticsListener owns platform dispatch. All these consumers use committed values;
they read the same Save. Runtime emits no new game/analytics event. Binding Settings
screen to Runtime is explicit. Native slider gestures persist on released preview
intent; programmatic refresh must not write or request sound. Toggles persist their
native changed intent. Text-size options are the three closed values, no free input.
Errors retain committed controls and expose an explicit retry action.

`Save.configure_system_defaults(reduced_motion: bool, language: String = "pl") -> Error`
is a before-load, closed initial preference injection. It affects only the newly
created document, never a loaded/migrated/recovered existing document. Callers provide
an observed OS motion preference and a language already filtered to shipped content.
No native OS motion API is assumed: unsupported observation keeps the normal default
and remains a platform/device gate. No persisted OS-observed flag is added.
This hook is unactivated by existing boot in this wave.

## Content-coherent language (T-0287)

The selector enumerates valid shipped manifests, not translations alone. Production
choices are PL until another content language ships. Language change must validate
content before persisting, retain each language's campaign state, and then apply UI
and content together through the caller-owned reload hook. Failed persistence/reload
cannot claim a successful switch; retry retains identity and previous presentation.
The initial device language chooses its shipped base locale or PL, only for a new
install through configure_system_defaults. Existing selection is never overwritten.

Before EN content ships, English UI is a labelled debug-only transient preview;
Save.language and Content.language remain PL. Release UI never exposes that preview.
Screens retranslate in place; no separate persisted UI-language preference is added.
Language switching while a board is active requires the caller to persist it before
reload; unsafe/unavailable reload is rejected, not silently discarded.

## Verification and external gates

Tests cover working-vs-committed values, invalid/failed/busy writes, retry and signal
reentry, existing/new-install defaults, six themes, live tokens/volumes/haptics,
layout/scroll/keyboard/lifecycle and supported-language filtering. Every screen task
supplies native three-class PL/PSEUDO default/HC130 evidence. Physical device/taste,
OS integration, native store/consent actions and external links remain explicit
release gates; native desktop evidence does not certify them.

### T-0287 preflight: explicit reload boundary

Content has `load_manifest(language, root)`, preserving its previous state on
failure, but no staged adoption or screen reload API. Settings does not own Nav
or Progress. The explicit `SettingsLanguage extends Node` hook therefore requires
`reload(phase: StringName, target: String) -> Error`, synchronously:

- `prepare`: caller durably checkpoints any active board, validates/prepares its
  replacement and holds the old presentation safely until completion. An unsafe
  or unavailable caller returns an error without discarding the board.
- `apply`: after the target setting is committed, caller loads the bound actual
  Content and publishes its prepared replacement together. Error must preserve
  the previous Content/presentation; returning OK certifies the target manifest.
  The controller independently verifies Content language/hash before publishing
  success or applying TranslationServer locale. Hooks must not await or replace
  the controller's pending request reentrantly.

`configure(save: Node, content: Node, reload: Callable, root: String =
"res://content", debug_preview: bool = false) -> Error` binds loaded coherent
owners. `choices() -> Array[Dictionary]` returns copied IDs/names/debug flags;
`snapshot() -> Dictionary` exposes presentation language, preview, pending target,
state and error. `select(language: String) -> Error` and `retry() -> Error`
serialize one exact target/manifest identity. Signals `changed` and
`failed(error: Error)` report real state. There is no boot/Nav activation.

States are `ready`, `prepare_failed`, `write_failed`, `reload_pending` and
`validation_failed`. Every failure preserves the old displayed language and keeps
an explicit retry for the same target. Persistence can complete before reload:
in `reload_pending` Save.language can already be the target, while the previous
Content/UI stays presented. The selector explicitly displays that pending state,
does not label it selected and does not allow another choice or Back. A successful
unrelated Save flush may resolve a failed write; the controller resumes through
the same hook, never silently equating persistence with reload success. The caller
holds the safe checkpoint until apply succeeds. Hook contract violations fail
closed and never emit a successful switch.

Manifest discovery uses the actual Content validator on each language directory;
translation CSVs never establish availability. An immutable packaged content root
is expected in production. Retry rejects a changed manifest identity. Per-language
progress is left with its existing owner; only Save's language setting changes.
`initial_language(device_locale, root)` filters a normalized base locale to this
catalog or PL. `configure_initial_defaults(save, reduced_motion, device_locale,
root)` feeds the filtered value to the before-load Save hook, without OS probing.

Before EN content ships, `preview_en` is an optional OS-debug-build-only transient
choice; `restore_preview` restores the actual content locale. Preview changes UI
locale only, never Save/Content, is clearly labelled and resets when its owner
leaves the tree. Passing debug_preview=false always yields production choices;
release builds cannot enable preview even when a caller requests it.

## Offline credits catalog (T-0339)

`SettingsCredits extends RefCounted` exposes static `entries() -> Array[Dictionary]`.
Each call returns seven fresh dictionaries with `id:StringName` and `notice:String`:
godot, godot-copyrights, godot-licenses, inter, lucide, audio, pl-sources. Engine
licence text is verbatim; all third-party copyright data is preserved as indented
JSON, alongside every full Engine licence text in sorted-name order. Font/icon
notices come from their existing exportable metadata without editing legal text.
Audio and content notices come from generated Resource metadata, never raw files
at runtime. `python tools/generate_credits.py --check` is enforced by tools tests;
regeneration embeds the current canonical NOTICE files. No export filter change.

These are original-language legal data, not translated UI copy. T-0288 owns the
licences view and translated navigation labels. No native SDK is currently
activated; adding native providers, final assets or new source data requires
updating the credits before release. This catalog is not legal/store approval.

## Licences screen (T-0340)

`LicencesScreen extends ScreenScaffold` in `features/settings/licences_screen.tscn`
consumes the complete seven-entry SettingsCredits catalog. Its ListRow index opens
an exact, untranslated plain-text notice, with a translated heading inside the
vertical scroll area. The TopBar keeps the short licences title at every text size.
No BBCode, hyperlinks or network action is interpreted from legal text.

`select_notice(id:StringName) -> Error` rejects before-ready/unknown selections
without mutation and starts a valid notice at its top, with scroll keyboard focus.
`handle_back() -> void` returns detail to the list, restoring list scroll/focus;
from the index it emits `back_requested`. Retained reentry preserves selection.
Rows/TopBar and detail headings retranslate live; legal text stays byte-identical.
Theme inheritance uses the caller's existing generated theme; no Save writes occur.

Composition remains explicit: caller handles SettingsScreen.action_requested with
`licences` by mounting this scene and handles back_requested to return. Integration
tests exercise that actual route. Global Settings boot/Nav activation remains open,
as do T-0288 restore/consent/browser/support integrations and physical-device review.

## Restore result dependency (T-0341)

Future T-0288 restore UI consumes Monetization.restore_snapshot/restore_changed,
not Events telemetry. Requested is acceptance, not restored/empty success. Only
completed permits an aggregate result/count. Unknown requires an explicit retry;
settling requires retry_restore_settlement without a second provider restore.
No Settings row binding or global activation is added by this contract task.
