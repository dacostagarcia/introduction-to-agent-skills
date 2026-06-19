# Common Agentic Patterns

A reference guide for the most-used composition patterns in Claude Code agentic systems.

## The Read–Reason–Write Pattern

The simplest agentic pattern: read input, apply LLM reasoning, write output.

```
Read tool → [LLM reasoning in-context] → Write tool
```

**When to use:** A single, self-contained transformation. The document to be transformed
is small enough that reading it does not bloat the context window excessively.

**Risk:** For large documents, the full content ends up in context and stays there for
the duration of the session. If the session continues after the write, the document
content is dead weight.

**Mitigation:** Wrap in a subagent. The subagent reads the large document, reasons over
it, writes the output — and its context is discarded. The caller only sees the result.

## The Fan-Out Pattern

Multiple independent tasks run in parallel via subagents, results collected by the orchestrator.

```
Orchestrator
  ├─► subagent A (isolated)
  ├─► subagent B (isolated)
  └─► subagent C (isolated)
  └─► collect & synthesize (in-context, small)
```

**When to use:** A set of independent subtasks that can run concurrently. Each subtask
is large enough to warrant isolation. The orchestrator needs only the summaries, not the
full intermediate work of each agent.

**Example:** Digesting a corpus of documents — one subagent per document, each returning
a two-paragraph summary. The orchestrator synthesizes the summaries into a final report.

**Cost advantage:** Three subagents each spending 10k tokens of intermediate context
cost the orchestrator 0 tokens of that work. It only pays for the three summaries
(perhaps 3 × 200 tokens). Net win: 90%+ context savings for the orchestrator.

## The Guard Pattern

A validation step runs before (and/or after) the main action.

```
pre-guard skill → main action → post-guard skill
```

**When to use:** High-stakes operations where you want a deterministic check before the
LLM acts (e.g. confirm the file path exists and is writable before generating content
to write to it), or a validation step after (e.g. confirm the output matches the
expected schema).

**Important:** Guards should be deterministic (tool calls, bash checks) when possible,
not LLM-based. An LLM guard that can be argued out of its check is not a guard.

## The Retry-Until Pattern

The agent loops until a condition is met or a max-attempts limit is hit.

```
while (not done && attempts < max):
  attempt action
  check result
  if failed: adjust and retry
```

**When to use:** Tasks that may fail on the first attempt due to external conditions
(network timeouts, partial data, rate limits). The LLM can reason about the failure
and adjust its approach before retrying.

**Warning:** Unbounded retry loops are dangerous. Always set a max-attempts guard and
log each attempt. An infinite retry loop on a Slack post will run until your context
window or credit runs out.
