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
