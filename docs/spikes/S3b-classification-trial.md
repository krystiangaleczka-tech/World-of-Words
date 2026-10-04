# S3b — Polish AI classification trial

Date: 2026-10-04. Task: T-0031.

## Status

BLOCKED before the two-model run.

Everything that can be prepared without credentials or a second-model runtime is frozen below:
the 200-word sample, identical prompt/schema, disagreement rules, metrics and current public price basis.
This report intentionally does not claim an agreement rate. The current Sol session cannot call a second
external model, and AGENTS.md S11 forbids inventing or adding provider secrets as part of this task.

## Trial question

Can two cheap models classify Polish word familiarity and sensitivity consistently enough that Phase 2
can batch-classify tens of thousands of words while sending only meaningful disagreements to Chris?

AI is not a validity authority. SJP.PL remains the only external validity authority selected by
decision 0008; the model output is advisory metadata only.

## Sample

File: docs/spikes/S3b-classification-sample.json

Exactly 200 unique Polish tokens, all 3-7 characters:
- 120 common words;
- 40 obscure/legacy words;
- 40 sensitive or ambiguity-probing words.

The sample_stratum field exists only to audit sample composition. A model run receives only the word
column, so the stratum cannot leak the expected answer.

## Candidate models

Use two distinct cheap models with identical inputs:
1. OpenAI gpt-6-luna.
2. Google gemini-2.5-flash-lite.

Why these two: both are current low-cost general text models suitable for high-volume classification,
and using different providers gives a stronger disagreement signal than two prompts on one model.

Pricing checked 2026-10-04 from official provider pages:
- gpt-6-luna standard: USD 0.10 / 1M input tokens, USD 0.50 / 1M output tokens.
  Source: https://developers.openai.com/api/docs/models and
  https://developers.openai.com/api/docs/pricing
- gemini-2.5-flash-lite standard: USD 0.10 / 1M text input tokens,
  USD 0.40 / 1M output tokens.
  Source: https://ai.google.dev/gemini-api/docs/pricing

Do not substitute an alias silently. Record the exact model ID returned/used by the provider.

## Frozen prompt v1

Use the same prompt text for both providers. Run with no web/tools and deterministic/lowest-variance
settings supported by the provider.

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

## Output schema

Conceptual record:

    {
      "word": "example",
      "familiarity": 0,
      "sensitivity": "safe",
      "flags": []
    }

The provider may use JSON array or provider-native structured output, but the normalized fields above
must be identical.

## Run protocol

- Five logical batches of 200 words are the production planning unit; this spike itself is one batch
  of 200 words per model.
- Pass only the word values from the JSON.
- No search, grounding or external tools.
- Record per provider: model ID, request mode, input tokens, output tokens, retries and billed cost.
- Malformed output: retry once using the exact same prompt. A second failure stays an error row.
- Never repair a model answer by hand before computing agreement.
- Human decisions are recorded only after the disagreement queue is produced.

## Agreement metrics

For N=200:
- exact familiarity agreement = count(A.familiarity == B.familiarity) / N
- within-one familiarity agreement = count(abs(A.familiarity - B.familiarity) <= 1) / N
- exact sensitivity agreement = count(A.sensitivity == B.sensitivity) / N
- actionable disagreement = sensitivity differs OR familiarity differs by >=2 OR a flag difference
  changes review/block handling
- actionable disagreement rate = actionable_disagreement_count / N
- provider error rate = missing/malformed rows after the one allowed retry / N

Report metrics overall and by sample_stratum. The stratum split is diagnostic only; it must not be fed
to models.

## Chris review queue

After both runs, produce a compact table containing only actionable disagreements with:
word, A familiarity/sensitivity/flags, B familiarity/sensitivity/flags, disagreement reason,
Chris decision, Chris note.

Chris reviews this queue, not all 200 words. His decision does not become a word-validity override;
it is evidence for the future classification/tier rules.

## Cost planning

The final T-0031 number must use actual provider token usage. Until the run exists, use this conservative
planning envelope for 1,000 words per model:
- about 4,000 input tokens total, including repeated prompt/schema overhead;
- about 25,000 output tokens for compact structured records.

At standard list prices this envelope gives:
- gpt-6-luna: 4k * USD 0.10/1M + 25k * USD 0.50/1M = about USD 0.0129 / 1,000 words;
- gemini-2.5-flash-lite: 4k * USD 0.10/1M + 25k * USD 0.40/1M =
  about USD 0.0104 / 1,000 words;
- combined provisional estimate: about USD 0.0233 / 1,000 words.

For planning before the measured run, use USD 0.05 / 1,000 words as a 2x rounded safety cap for the
two-model classification pass. This is a budget guardrail, not the completed T-0031 measured figure.

At that guardrail, 50,000 words would cost about USD 2.50 for the two-model pass before retries.
Human review time is expected to dominate API spend.

## Completion gate

T-0031 can move from blocked to review only when:
1. both listed models (or two explicitly recorded replacements) actually process all 200 words;
2. raw normalized outputs are available for comparison;
3. actual token usage and cost replace the provisional estimate;
4. agreement metrics and Chris's disagreement queue are filled in;
5. no secret is committed.

## Escalation

S11 — the current Sol execution environment has no callable second-model runtime. Completing the
empirical model-vs-model requirement would require external model access/credentials, which this task
must not invent, request into the repository or expose. The trial has therefore been prepared to the
point immediately before provider execution, and no fabricated agreement number is recorded.
