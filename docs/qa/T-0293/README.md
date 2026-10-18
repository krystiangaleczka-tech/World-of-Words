# Accessibility pass — T-0293

Three focused integration tests exercise all six catalog types in PL/EN,
token touch minimums, focus policy, Level load/bonus/hint/completion/restore/missing
content and locale refresh. Existing catalog metadata remains unchanged.

Native evidence: 12 Level captures (three layouts × PL/PSEUDO × default/HC130),
plus summaries.json recording the actual native accessibility properties. Reproduce:

```sh
DISPLAY=:106 /tmp/wow-godot/Godot_v4.7.2-stable_linux.x86_64 --path game --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script ../docs/qa/T-0293/capture.gd
```

No new visible widget/focus stop is added. References: DESIGN.md accessibility
and Level P2 specifications. Decision 0001 records the unavailable mobile reader
bridge: these desktop checks do not certify TalkBack/VoiceOver or physical-device
usability. Native settings rows not yet built under T-0288 remain outside this pass.
