# T-0179 — Collect outsider playtest observations

This worksheet supports pending T-0141 using the [current P1 protocol](T-0154-playtest-baseline.md).
It records operator-entered observations. Tools check format and report coverage;
Chris evaluates truth, reference-device feel and FUN GATE separately.

## Prepare a round

Use the same recorded build for five people outside the project. Retain T-0139
feel/device and T-0140 word-review prerequisites. The prior S26 Ultra approval is
already recorded; it does not supply Galaxy A15 feel evidence or outsider sessions.
The original Astra audit remains separate.

Use an isolated clean test campaign starting at slot 1 for each person. Hide
answers and debug overlays. Do not reset Chris's personal campaign or uninstall
his test installation to prepare the round. Debug completion is not human solving.
Do not give instructions or help; if help occurs, record it rather than hiding it.
Observe at least 20 active minutes per person; exclude pauses. Record early exits
at their actual duration. Keep participants anonymous (P01..P05), without names.

Record the actual APK file's SHA-256, the exact source commit of the build and
its content-pack SHA-256. An artifact ZIP digest is not the APK digest, and the
current checkout or squash merge may differ from the CI artifact's source head.
Use the selected successful CI run's source identity; preserve that build through
the round. Obtain the source/content identities from the same build, not a newer
checkout. Current P1 contains one pack, `game/content/pl/packs/c-0001-0065.json`;
`content_sha256` records that pack's bytes. Leave unknown identities null.

At a matching source checkout, examples to obtain hashes (substitute the APK path):

```sh
sha256sum /path/to/actual-debug.apk
sha256sum game/content/pl/packs/c-0001-0065.json
```

Copy intended common identity to `build`, and separately record each session's
actual identity. Fill date, device/model, Android version, refresh mode and power
saving state from the session. The tool compares hashes but does not inspect APK
bytes, detect the phone model or authenticate observations.

## Create and fill a worksheet

Run from the repository root:

```sh
uv run python tools/playtest_cli.py template > outsider-sessions.json
```

The five IDs are placeholders. All observations and hashes start null; notes are
empty. Keep a copy and fill it after actual sessions. `null` means not recorded;
`first_word: ""` means observed no self-discovered word; `stalls: []` means observed
no stalls. Record stalls as actual descriptions. `active_seconds: 0` is a known
zero duration, not missing. Use actual booleans for protocol observations, not
strings such as "yes". Notes may contain Polish text. Field definitions live in
[T-0175 schema](T-0175-playtest-evidence-contract.md).

## Validate and report

```sh
uv run python tools/playtest_cli.py validate outsider-sessions.json
uv run python tools/playtest_cli.py report outsider-sessions.json > outsider-report.md
uv run python tools/playtest_cli.py report outsider-sessions.json --format json > outsider-report.json
```

The commands read inputs and print stdout; shell redirection creates output files.
Use different input/output filenames: redirecting onto the input would truncate it
before the command reads. Keep the original worksheet and any source notes.

Exit 0 means valid format/output, including for a blank or assisted session.
Input, read or encoding errors use stderr and exit 1; usage errors exit 2. No
partial report is printed on input failure. JSON keys must be unique, including
inside sessions. Unknown/missing keys, wrong types, malformed dates/hashes,
nonfinite refresh values and duplicate participant IDs are rejected.

Reports retain raw observations, list missing evidence separately from known
protocol deviations, and show exact build mismatches. `recorded_sessions` counts
worksheet rows, not proof that five sessions occurred. Complete protocol records
have all required evidence recorded and no known deviations; this is a coverage
count, not acceptance. Unknown and observed yes/no continue answers remain separate.
A participant not wanting to continue is an observation, not a protocol violation.
Markdown escapes participant text; JSON retains it as entered.

## Human disposition

Review at least five actual outsider sessions, including first self-discovered
word, stalls/help, duration, final slot and desire to continue. Keep incomplete,
short or assisted records visible. Do not fill unknown observations from defaults,
automated tests or another person's results. Desktop synthetic fixtures are only
tooling tests. The worksheet does not close T-0139/T-0140/T-0141/T-0143, infer P2
entry, create phone observations or replace Chris's go / fix core / stop decision.
For separate engine performance captures use [T-0169](T-0169-device-performance-capture.md).
