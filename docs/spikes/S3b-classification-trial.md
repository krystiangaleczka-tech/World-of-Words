# S3b — Polish AI classification trial

Date: 2026-10-06. Task: T-0031, revision 2.

## Result and scope

The requested in-session comparison has executed: two independent agents classified the same 200
Polish tokens with the same frozen prompt. Both first-attempt outputs passed schema, uniqueness,
exact-token and order validation; no answers were edited and no retries were needed.
The measured agreement and actionable disagreement queue are below; both raw outputs are archived.

Chris explicitly selected this alternative after the session reported no authenticated provider APIs
or token/billing telemetry. Requested replacements: gpt-6-luna and gpt-6.1-sol. The latter is a reference
model, not a second cheap provider. This run does not measure the proposed Luna/Gemini production pair,
API cost per 1,000 words, classification accuracy or the cheap-executor Phase 0 gate.
Full ROADMAP completion remains blocked on those external measurements; Chris's disagreement review is complete.

AI is advisory metadata only. SJP.PL remains the validity authority from decision 0008.
No output here decides word validity, adds a word to production, or changes production tier rules.

## Sample

File: docs/spikes/S3b-classification-sample.json. Exactly 200 unique tokens, each 3–7 characters:
120 common, 40 obscure/legacy and 40 sensitive/ambiguous. This is a deliberately selected diagnostic
sample, not a random population sample. Models saw only the 200 word values in original order.
The strata were not sent to either agent and are used only for analysis after both runs.

## Run provenance

| Field | Luna | Sol |
|---|---|---|
| Model explicitly selected by orchestration | gpt-6-luna | gpt-6.1-sol |
| Provider-resolved/versioned ID independently exposed | unavailable | unavailable |
| Request mode | isolated in-session agent | isolated in-session agent |
| Reasoning setting | medium | medium |
| Conversation fork | none | none |
| Search, external grounding or another model | none | none |
| Record count | 200 | 200 |
| Schema/order/token errors | 0 | 0 |
| Retry count | 0 | 0 |
| Input/output token usage | unavailable | unavailable |
| Billed or list-price cost | unavailable | unavailable |
| USD per 1,000 words | not measured | not measured |

The configured model selector is recorded, rather than claiming an independently observed provider
version. Temperature and seed controls are not exposed by the agent tool; deterministic output is not
claimed. Both agents received the same wrapper instructions, differing only in their output path:
read the frozen prompt and word-only input; classify all 200 without other reports/models/tools;
write the raw JSON array; report unavailable model/usage/billing telemetry honestly.
No account identifiers or secrets are recorded.

SHA-256 digests of actual execution artifacts:

| Artifact | SHA-256 |
|---|---|
| Sample file | e0c4ff4a2c5cc914ff24a857f1a9b1611d696e70081be19242455b56ea3d75cc |
| Word-only input file | ce681ba95add1ed28980bea77d2bc46d5d9bf4ff4d15bf713674826e594f484a |
| Executed prompt UTF-8 bytes | 9ba9ed04d59aebd03a0b2ecfc41a5a19ef70ad1ae87ca94e48786becda089045 |
| Luna raw JSON UTF-8 bytes | 4223a0c0c95a6c34a0aaa028a22c8b7d2ab6404272552f9490296298663adfec |
| Sol raw JSON UTF-8 bytes | 0e0eaefcb095f66e95ae183d3b13f6eb2644861570c2f807af2089272e1e40e3 |

The word-only input is reproducible as UTF-8 `json.dumps([word for group in sample.values()
for word in group], ensure_ascii=False)` with default separators and no trailing newline.
The executed prompt and raw output code blocks below preserve their UTF-8 content, including the final
newline when present. Stratum labels, metrics and the other agent's answer were never input to a model.

## Frozen prompt v1 — actual executed text

```text
You are classifying Polish words for a mobile word puzzle.
You do NOT decide whether a token is a valid Polish word. Validity is handled by a licensed
dictionary outside this task.
For every input word return exactly:
- word: copy the input token unchanged
- familiarity: integer 0..3
  0 = unknown to an average adult Polish speaker / extremely obscure
  1 = uncommon, specialist, strongly regional, archaic or old-fashioned
  2 = widely understandable but not necessarily frequent in everyday speech
  3 = very common everyday vocabulary
- sensitivity: one of "safe", "review", "block"
  safe = ordinary content suitable for a general-audience word puzzle
  review = context-sensitive/adult/violent/substance-related/possibly offensive; human review
  block = plainly vulgar, explicit sexual content, slur/hate term, or otherwise clearly
          unsuitable as a normal level word
- flags: zero or more values from:
  archaic, vulgar, sexual, violence, alcohol_drugs, hate, proper_name, abbreviation, other
Treat familiarity and sensitivity independently. A vulgar word can be very familiar.
Do not add explanations, translations, validity judgments, replacement words or extra fields.
Return one structured record for every input word and preserve input order.
```

## Output schema and validation

Exactly four fields per record: word (unchanged input string), familiarity (integer 0..3, not a Boolean),
sensitivity (safe/review/block), flags (unique values from the prompt's allowed set). Exactly 200 rows
per output in input order. Invalid rows would be retried once with the same prompt; a second failure
would remain an error and a review item. This run required no retry or normalization/repair.

## Measured agreement

Percentages use the complete group denominator, not only selected matching rows. No missing rows.

| Group | N | Familiarity exact | Familiarity within one | Sensitivity exact | Actionable disagreements |
|---|---|---|---|---|---|
| overall | 200 | 187/200 (93.5%) | 200/200 (100.0%) | 193/200 (96.5%) | 8/200 (4.0%) |
| common | 120 | 120/120 (100.0%) | 120/120 (100.0%) | 120/120 (100.0%) | 0/120 (0.0%) |
| obscure_or_legacy | 40 | 32/40 (80.0%) | 40/40 (100.0%) | 39/40 (97.5%) | 2/40 (5.0%) |
| sensitive_or_ambiguous | 40 | 35/40 (87.5%) | 40/40 (100.0%) | 34/40 (85.0%) | 6/40 (15.0%) |

Agreement measures consistency, not accuracy. There is no human-labeled ground truth in this trial.
Both models can agree on a bad classification. The selected diagnostic strata cannot estimate
production prevalence or human review effort for the full Polish dictionary.

## Actionable disagreement rule — frozen before analysis

Queue a token when sensitivity differs, familiarity differs by at least two points, or a flag difference
changes effective review/block handling. For the flag check, rank safe=0, review=1, block=2;
flag ranks are block for vulgar/sexual/hate, review for violence/alcohol_drugs/proper_name/abbreviation/other,
and neutral for archaic. Effective handling is the maximum of declared sensitivity and flag rank.
This is a trial review-routing definition, not a production classifier or word-validity decision.
A harmless archaic-flag mismatch alone does not cause an actionable disagreement.

## Chris review queue — 8 tokens

Columns show familiarity / sensitivity / flags. Chris completed all eight sensitivity decisions on
2026-10-07: baba, hazard, kasyno and poker are safe; kurna, suka, burdel and orgazm are block.
Raw model answers stay unchanged. Every record remains auditable below.

| Word | Luna | Sol | Reason | Chris decision | Chris note |
|---|---|---|---|---|---|
| kurna | 2 / review / vulgar | 2 / review / other | flags change effective handling | block | Chris, 2026-10-07: explicitly rejected as unsuitable. |
| baba | 3 / safe / — | 3 / review / other | sensitivity differs, flags change effective handling | safe | Chris, 2026-10-07: explicitly accepted as OK. |
| suka | 3 / block / vulgar | 3 / review / vulgar | sensitivity differs | block | Chris, 2026-10-07: explicitly rejected as unsuitable. |
| burdel | 3 / review / sexual | 3 / block / vulgar, sexual | sensitivity differs | block | Chris, 2026-10-07: explicitly rejected as unsuitable. |
| orgazm | 2 / review / sexual | 3 / block / sexual | sensitivity differs | block | Chris, 2026-10-07: explicitly rejected as unsuitable. |
| hazard | 3 / safe / — | 3 / review / other | sensitivity differs, flags change effective handling | safe | Chris, 2026-10-07: explicitly accepted as OK. |
| kasyno | 3 / safe / — | 3 / review / other | sensitivity differs, flags change effective handling | safe | Chris, 2026-10-07: explicitly accepted as OK. |
| poker | 3 / safe / — | 3 / review / other | sensitivity differs, flags change effective handling | safe | Chris, 2026-10-07: explicitly accepted as OK. |

## Human review progress

Chris approved four tokens as safe on 2026-10-07: baba, hazard, kasyno, poker.
Chris rejected the remaining four as block on 2026-10-07: kurna, suka, burdel, orgazm.
All eight human decisions are recorded. This records sensitivity only;
no familiarity or raw model flags are rewritten and no production content is changed.

## Cost evidence and remaining gates

Input tokens, output/reasoning tokens and account billing are not exposed by these in-session tools.
Therefore per-model and combined paid-list-price cost per 1,000 words are unmeasured, not zero.
Historical preparation prices are omitted because they were not independently verified for these
selected models. Official sources for a later actual API run:
https://developers.openai.com/api/docs/models,
https://developers.openai.com/api/docs/pricing,
https://ai.google.dev/gemini-api/docs/pricing.
Verify the available exact API model IDs first; these selectors alone do not prove API availability.
A later measured API cost must include prompt repetition, returned/billable token usage and retries.

To complete the original ROADMAP gate: obtain the original two cheap-provider outputs (or a recorded
validated cheap replacement) and measured token/cost evidence. Chris's eight disagreement decisions
are now recorded above.
Do not use this reference-model comparison or fabricated zero cost as that evidence.

## Reproduction of comparison

Parse the two raw arrays, enforce schema and input order, then for each paired token count exact
familiarity, absolute familiarity gap ≤1, exact sensitivity and the actionable rule above. Divide by N
for overall and by-stratum metrics. No records were excluded, answers rewritten or labels inferred.
One-off analysis checks used known pairs to verify exact/within-one thresholds, sensitivity/flag
routing, neutral archaic behavior and rejection of Boolean familiarity values.
Repository changes remain the three allowlisted files; no production pipeline or game content changed.

## Archived raw Luna output

```json
[
{"word":"dom","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kot","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pies","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"las","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"woda","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"chleb","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"szkoła","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"praca","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"droga","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"miasto","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"wieś","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"morze","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rzeka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"góra","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pole","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ogród","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kwiat","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"drzewo","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"liść","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ptak","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ryba","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"koń","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"krowa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mysz","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ser","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mleko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"jajko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"zupa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ryż","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mak","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"sól","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"cukier","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kawa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"herbata","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"sok","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"wino","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"miód","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"jabłko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"gruszka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"śliwka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"noc","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dzień","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rano","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"wieczór","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"czas","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rok","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"miesiąc","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"tydzień","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"godzina","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"minuta","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"chwila","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"życie","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"śmierć","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"sen","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rodzina","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"matka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ojciec","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"brat","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"siostra","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dziecko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"syn","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"córka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"babcia","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dziadek","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kolega","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"gość","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pan","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pani","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"serce","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"głowa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ręka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"noga","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"oko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ucho","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"nos","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"usta","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ząb","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"głos","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"słowo","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"list","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"książka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"film","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"gra","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"muzyka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"radio","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"telefon","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ekran","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"auto","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pociąg","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rower","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"statek","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"samolot","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"sklep","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rynek","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"bank","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"park","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pokój","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kuchnia","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"stół","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"krzesło","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"łóżko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"drzwi","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"okno","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"klucz","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"torba","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"but","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kurtka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"koszula","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"spodnie","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"czapka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"piłka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mecz","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"bieg","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"spacer","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"taniec","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dobry","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"zły","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mały","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"duży","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"nowy","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"waść","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"imć","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"alkierz","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"żupan","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"kontusz","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"fryc","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"bław","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"wasal","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"ceber","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"kierz","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"łan","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"mendel","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"pacht","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"rajtuz","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"sakwa","familiarity":2,"sensitivity":"safe","flags":["archaic"]},
{"word":"szeląg","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"trzos","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"żerdź","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"żłób","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"miedza","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"runo","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"rżysko","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"siodło","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"cep","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"żarna","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"gont","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"kagan","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"kram","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"młaka","familiarity":0,"sensitivity":"safe","flags":[]},
{"word":"perć","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"smrek","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"turnia","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"kurna","familiarity":2,"sensitivity":"review","flags":["vulgar"]},
{"word":"fajka","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"dryblas","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"baba","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"chwat","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"hultaj","familiarity":2,"sensitivity":"safe","flags":["archaic"]},
{"word":"wałkoń","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"zuch","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dupa","familiarity":3,"sensitivity":"block","flags":["vulgar"]},
{"word":"seks","familiarity":3,"sensitivity":"review","flags":["sexual"]},
{"word":"porno","familiarity":3,"sensitivity":"block","flags":["sexual"]},
{"word":"nagość","familiarity":2,"sensitivity":"review","flags":["sexual"]},
{"word":"gwałt","familiarity":3,"sensitivity":"review","flags":["violence","sexual"]},
{"word":"krew","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"trup","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"zwłoki","familiarity":2,"sensitivity":"review","flags":["violence"]},
{"word":"zgon","familiarity":2,"sensitivity":"review","flags":["violence"]},
{"word":"mord","familiarity":2,"sensitivity":"review","flags":["violence"]},
{"word":"zabić","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"ranić","familiarity":2,"sensitivity":"review","flags":["violence"]},
{"word":"nóż","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"broń","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"bomba","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"wojna","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"terror","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"żyletka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kurwa","familiarity":3,"sensitivity":"block","flags":["vulgar"]},
{"word":"chuj","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"gówno","familiarity":3,"sensitivity":"block","flags":["vulgar"]},
{"word":"pizda","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"cipka","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"fiut","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"suka","familiarity":3,"sensitivity":"block","flags":["vulgar"]},
{"word":"dziwka","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"burdel","familiarity":3,"sensitivity":"review","flags":["sexual"]},
{"word":"erotyka","familiarity":2,"sensitivity":"review","flags":["sexual"]},
{"word":"orgazm","familiarity":2,"sensitivity":"review","flags":["sexual"]},
{"word":"wódka","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"piwo","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"ćpun","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"dragi","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"joint","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"koks","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"hasz","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"marycha","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"hazard","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kasyno","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"poker","familiarity":3,"sensitivity":"safe","flags":[]}
]
```

## Archived raw Sol output

```json
[
{"word":"dom","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kot","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pies","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"las","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"woda","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"chleb","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"szkoła","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"praca","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"droga","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"miasto","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"wieś","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"morze","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rzeka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"góra","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pole","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ogród","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kwiat","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"drzewo","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"liść","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ptak","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ryba","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"koń","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"krowa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mysz","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ser","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mleko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"jajko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"zupa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ryż","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mak","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"sól","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"cukier","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kawa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"herbata","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"sok","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"wino","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"miód","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"jabłko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"gruszka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"śliwka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"noc","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dzień","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rano","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"wieczór","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"czas","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rok","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"miesiąc","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"tydzień","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"godzina","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"minuta","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"chwila","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"życie","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"śmierć","familiarity":3,"sensitivity":"review","flags":["other"]},
{"word":"sen","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rodzina","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"matka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ojciec","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"brat","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"siostra","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dziecko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"syn","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"córka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"babcia","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dziadek","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kolega","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"gość","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pan","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pani","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"serce","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"głowa","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ręka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"noga","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"oko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ucho","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"nos","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"usta","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ząb","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"głos","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"słowo","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"list","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"książka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"film","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"gra","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"muzyka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"radio","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"telefon","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"ekran","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"auto","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pociąg","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rower","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"statek","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"samolot","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"sklep","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"rynek","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"bank","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"park","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"pokój","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kuchnia","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"stół","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"krzesło","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"łóżko","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"drzwi","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"okno","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"klucz","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"torba","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"but","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kurtka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"koszula","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"spodnie","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"czapka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"piłka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mecz","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"bieg","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"spacer","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"taniec","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"dobry","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"zły","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"mały","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"duży","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"nowy","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"waść","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"imć","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"alkierz","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"żupan","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"kontusz","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"fryc","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"bław","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"wasal","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"ceber","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"kierz","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"łan","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"mendel","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"pacht","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"rajtuz","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"sakwa","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"szeląg","familiarity":2,"sensitivity":"safe","flags":["archaic"]},
{"word":"trzos","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"żerdź","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"żłób","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"miedza","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"runo","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"rżysko","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"siodło","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"cep","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"żarna","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"gont","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"kagan","familiarity":0,"sensitivity":"safe","flags":["archaic"]},
{"word":"kram","familiarity":2,"sensitivity":"safe","flags":["archaic"]},
{"word":"młaka","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"perć","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"smrek","familiarity":1,"sensitivity":"safe","flags":[]},
{"word":"turnia","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"kurna","familiarity":2,"sensitivity":"review","flags":["other"]},
{"word":"fajka","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"dryblas","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"baba","familiarity":3,"sensitivity":"review","flags":["other"]},
{"word":"chwat","familiarity":1,"sensitivity":"safe","flags":["archaic"]},
{"word":"hultaj","familiarity":2,"sensitivity":"safe","flags":["archaic"]},
{"word":"wałkoń","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"zuch","familiarity":2,"sensitivity":"safe","flags":[]},
{"word":"dupa","familiarity":3,"sensitivity":"block","flags":["vulgar"]},
{"word":"seks","familiarity":3,"sensitivity":"review","flags":["sexual"]},
{"word":"porno","familiarity":3,"sensitivity":"block","flags":["sexual"]},
{"word":"nagość","familiarity":2,"sensitivity":"review","flags":["sexual"]},
{"word":"gwałt","familiarity":3,"sensitivity":"review","flags":["sexual","violence"]},
{"word":"krew","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"trup","familiarity":3,"sensitivity":"review","flags":["other"]},
{"word":"zwłoki","familiarity":3,"sensitivity":"review","flags":["other"]},
{"word":"zgon","familiarity":2,"sensitivity":"review","flags":["other"]},
{"word":"mord","familiarity":2,"sensitivity":"review","flags":["violence"]},
{"word":"zabić","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"ranić","familiarity":2,"sensitivity":"review","flags":["violence"]},
{"word":"nóż","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"broń","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"bomba","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"wojna","familiarity":3,"sensitivity":"review","flags":["violence"]},
{"word":"terror","familiarity":2,"sensitivity":"review","flags":["violence"]},
{"word":"żyletka","familiarity":3,"sensitivity":"safe","flags":[]},
{"word":"kurwa","familiarity":3,"sensitivity":"block","flags":["vulgar"]},
{"word":"chuj","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"gówno","familiarity":3,"sensitivity":"block","flags":["vulgar"]},
{"word":"pizda","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"cipka","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"fiut","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"suka","familiarity":3,"sensitivity":"review","flags":["vulgar"]},
{"word":"dziwka","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"burdel","familiarity":3,"sensitivity":"block","flags":["vulgar","sexual"]},
{"word":"erotyka","familiarity":2,"sensitivity":"review","flags":["sexual"]},
{"word":"orgazm","familiarity":3,"sensitivity":"block","flags":["sexual"]},
{"word":"wódka","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"piwo","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"ćpun","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs","other"]},
{"word":"dragi","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"joint","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"koks","familiarity":3,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"hasz","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"marycha","familiarity":2,"sensitivity":"review","flags":["alcohol_drugs"]},
{"word":"hazard","familiarity":3,"sensitivity":"review","flags":["other"]},
{"word":"kasyno","familiarity":3,"sensitivity":"review","flags":["other"]},
{"word":"poker","familiarity":3,"sensitivity":"review","flags":["other"]}
]
```
