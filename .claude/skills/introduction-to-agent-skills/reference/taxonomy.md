# Taxonomy Reference: Skills, Subagents, Agents, Agent Loops

*Deep reference for `introduction-to-agent-skills`. Not loaded until you open this file —
progressive disclosure in action.*

All examples use the **document digester** from this repo.

---

## The core trade-off: reasoning vs determinism

Every agentic design decision is about one question:
**does this step require LLM reasoning, or can it be deterministic?**

Reasoning is expensive (tokens, latency, non-determinism).  
Determinism is cheap, fast, and reproducible.

The four primitives let you push as much as possible into the deterministic bucket
and save reasoning for the parts that genuinely need it.

```
deterministic ◄──────────────────────────────────────────────────► reasoning
  Tools/MCP       Skill         Subagent     Agent definition    Agent loop
  (pure I/O)  (in-context    (isolated,    (named, isolated,   (orchestrator,
               instructions) fork pattern)  fixed tools)        decides + loops)
```

---

## 1. Tool / MCP

**What:** A deterministic function. Takes inputs, performs a bounded action, returns
outputs. No LLM reasoning inside. Examples: `Read` (read a file), `Bash` (run a
command), `WebFetch` (fetch a URL), a Slack MCP tool (post a message).

**Cost:** Negligible. No context is consumed; the tool call and its result add a small
fixed amount to the session. No reasoning overhead.

**Digest example:** `wc -w sample-doc.md` (counts words), `Read sample-doc.md` (reads
the file). Both are deterministic. Neither needs an LLM.

**Decision rule:** If a bash command or API call can do it, use a tool. Never route a
deterministic action through an LLM.

**Anti-pattern:** Wrapping `curl` in an "AI step" that always makes the same call.

---

## 2. Skill

**What:** A packaged set of instructions in a `SKILL.md` file, invoked by name.
The caller loads **only** `name` + `description` until the skill is invoked — zero
tokens for 30 skills in your library, because only their two-line summaries are ever
in context. When invoked, the full body loads and the model follows it **in the
caller's context window**.

**Cost:** Zero until invoked. After invocation: the body + any tool calls accumulate
in the caller's context. For short documents and small tasks, this is fine.

**Digest example:** `/digest-skill sample-doc.md "risks" short`
- The skill body loads here.
- `sample-doc.md` is read into the session.
- The digest is produced in-context.
- After this skill finishes, the full doc content is in your history.

**Decision rule:** Use a skill for reusable workflows that are small-to-medium in size
and where the caller either needs to see the intermediate work, or the task is small
enough that context accumulation doesn't matter.

**Progressive disclosure:** Deep content should be in `reference/` sub-files linked
from the body — they only load if explicitly opened. This file is an example.

**Anti-pattern:** One 500-line monolithic skill body. Split responsibilities. Skills compose.

---

## 3. Subagent (`context: fork`)

**What:** The same `SKILL.md` with `context: fork` in the frontmatter. The runtime
creates a **fresh, empty context window**, runs the skill inside it, and returns only
the **final output** to the caller. The forked context is then discarded. The caller's
context grows only by the size of the summary returned.

**Cost:** The subagent pays for its own context. The caller pays for the summary.
For a 5,000-word document: the subagent might spend 10k tokens reading and reasoning;
the caller receives a 200-token summary and pays nothing for the intermediate work.

**Digest example:** `/digest-subagent sample-doc.md "risks" short`
- A fresh context is created.
- `sample-doc.md` is read *there*, not here.
- The digest is produced *there*.
- Only the digest returns here. The doc content is gone.
- Your session history grew by ~200 tokens, not 5,000.

**The one-line difference:**

```yaml
# digest-skill (in-context)
name: digest-skill

# digest-subagent (isolated) — the ONLY change:
name: digest-subagent
context: fork
agent: You are a focused document digester running in an isolated context.
```

Run `git diff --no-index digest-skill/SKILL.md digest-subagent/SKILL.md` to see this.

**Decision rule:** Use a subagent when the task is large (the intermediate work would
bloat the caller's context) or independent (the caller doesn't need to see the steps).

**Anti-pattern:** Forking for a 10-line task. Fork overhead has a cost; it's not free.
Use it when isolation pays off.

---

## 4. Agent definition (`.claude/agents/NAME.md`)

**What:** A named, reusable executor with a fixed system prompt, toolset, and model.
Lives in `.claude/agents/NAME.md`. Any orchestrator can delegate to it by name via the
Agent tool. **Always runs isolated** — agent definitions always behave like subagents.

**How it differs from a subagent:**
- A subagent is a *relationship*: this skill, run isolated, for this call.
- An agent definition is a *thing*: a named executor that persists across sessions,
  can be delegated to by multiple orchestrators, has a fixed model and toolset.

**Digest example:** `.claude/agents/digester.md`
- Model: `claude-haiku` (cheap, fast — digesting doesn't need heavy reasoning).
- Tools: `Read`, `Bash` only — no network access, no writes.
- Any orchestrator can say "use the digester agent on file X" and get a digest back.
- The digester can't accidentally fetch URLs or write files — its blast radius is fixed
  in the definition, not in the call site.

**Decision rule:** Use an agent definition when:
- Multiple orchestrators need the same isolated executor.
- You want to fix the model or toolset at definition time, not call time.
- The executor represents a role (researcher, writer, digester) that should have
  stable, auditable capabilities.

**Anti-pattern:** Creating an agent definition for a one-off task. If only one
orchestrator ever calls it, a subagent skill is simpler.

---

## 5. Agent loop

**What:** The orchestrator — typically a headless LLM invocation (`claude --print`)
running on a schedule or triggered by an event. Reads a goal, decides which skills,
subagents, or tools to invoke, observes results, loops until done.

**Cost:** The most expensive primitive. Every loop iteration is an LLM call. Design
the loop to be thin — a decision layer, not an execution layer.

**Digest example:** `digest-all.sh`
```bash
for doc in docs/*.md; do
  claude --print --allowedTools "Read,Bash" "/digest-subagent $doc short"
done
```
The loop contains: file iteration, invocation, logging. Zero business logic.
The business logic (how to digest) lives in `digest-subagent/SKILL.md`.

**Control-plane decoupling:** Three layers, each replaceable independently:
1. **When to run** — cron, CI trigger, event webhook (not the LLM's concern).
2. **What to run** — the skill (the LLM's instructions, not the orchestrator's).
3. **How to deliver** — a tool (Bash, MCP, curl — not the LLM's reasoning).

**Decision rule:** Use an agent loop for automation that must run unattended. If a
human is in the loop, a skill is usually enough.

**Anti-pattern:** The agent loop containing business logic. If your loop script has
`if/else` on digest content, move that logic into the skill. The loop decides
*when* and *what*; the skill decides *how*.

---

## Cost comparison on the digest task

| Expression | Caller context cost | Subagent context cost | Model |
|---|---|---|---|
| `/digest-skill sample-doc.md` | Full doc + digest | — | Session model |
| `/digest-subagent sample-doc.md` | Digest summary only | Full doc + digest | Session model |
| Agent tool → digester | Digest summary only | Full doc + digest | Haiku (cheap) |
| `digest-all.sh` (loop) | Per-doc summary × N | Full doc + digest per doc | Session model |

The loop row shows why agent loops are expensive at scale: N documents = N full LLM
invocations, each paying for its own context.

---

## Anti-patterns quick reference

| Anti-pattern | Better approach |
|---|---|
| LLM reasoning for deterministic actions | Move to a tool or bash script |
| Giant monolithic skill body | Split into `reference/` files; compose skills |
| Forking a 5-line skill | Keep in-context; fork overhead isn't free |
| Business logic in the agent loop script | Move into the skill body |
| Agent definition for a one-off task | Use a subagent skill instead |
| Secrets in skill files | `.env` only (gitignored); pass via environment |
| Subagent output with no schema | Define expected output format in the skill body |
