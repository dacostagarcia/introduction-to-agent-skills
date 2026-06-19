# RFC-0042: Unified Agentic Architecture for Distributed AI Systems

**Status:** Draft  
**Authors:** Platform AI Team  
**Created:** 2026-06-01  
**Last updated:** 2026-06-15  

---

## Abstract

This RFC proposes a unified architecture for building agentic AI systems at scale. It
covers the decomposition of autonomous workflows into reusable primitives — tools,
skills, subagents, and agent loops — and establishes design principles for composing
them reliably, safely, and cost-effectively.

The core thesis: most of what teams currently build as "agents" should be implemented
as skills or tools. LLM reasoning should be reserved for judgment and orchestration, not
for work that can be deterministic.

---

## 1. Background

### 1.1 The proliferation problem

Over the last 18 months, every team in the organization has independently built some
form of "AI agent." The implementations share almost no structure. Some are monolithic
system prompts hundreds of lines long. Others are long-running Python processes with
embedded LLM calls. A few are single large functions that do everything: fetch, reason,
summarize, and deliver — all in one shot.

The consequences are predictable:

- **Context bloat.** Agents accumulate tens of thousands of tokens of history before
  producing output. This is slow and expensive, and the model's attention degrades over
  the long context window.
- **Non-determinism where you want reliability.** Tasks that should have fixed outputs
  (format a report, post to Slack, read a config file) are run through the LLM
  unnecessarily, introducing variability and failure modes.
- **Zero reuse.** The same "summarize a document" logic is reimplemented in seven places
  because there's no shared primitive for it.
- **Testing is impossible.** A 400-line system prompt with embedded logic and tool calls
  is not a unit — it cannot be tested in isolation.

### 1.2 What we actually need

What teams need is a vocabulary. Four concepts, each with a clear definition and a
clear rule for when to reach for it. Once those four concepts are shared, systems become
composable, reviewable, and teachable.

---

## 2. The Four Primitives

### 2.1 Tool

A **tool** is a deterministic function. It takes inputs, performs a bounded action, and
returns outputs. No LLM reasoning occurs inside a tool. Examples: read a file, make an
HTTP request, run a SQL query, post a Slack message.

**Design rule:** If a `bash` one-liner can do it, it's a tool. Don't route it through
a language model.

**Cost model:** Negligible. Tools are fast, predictable, and cheap. They are the
system's hands, not its brain.

**Anti-pattern:** Wrapping a deterministic action in an "AI-powered" abstraction when
the action is always the same. If you're using an LLM to "decide" to always call
`curl https://api.example.com/status`, you're burning money for nothing.

### 2.2 Skill

A **skill** is a packaged set of instructions — a deterministic workflow expressed in
natural language and structured constraints. It is stored as a document (a `SKILL.md`),
and it is invoked by name.

The key property of a skill is **progressive disclosure**: the caller only loads the
skill's `name` and `description` into its context window until the skill is actually
invoked. A library of 30 skills costs zero tokens — only the two-line summaries are
ever in context. When invoked, the skill's body loads into the **caller's** context and
the model follows its instructions.

**Design rule:** If you're repeating the same structured workflow (with defined inputs,
defined steps, and defined output format), it's a skill. Name it. Package it. Invoke it.

**Cost model:** Zero until invoked. After invocation, the skill body and its tool calls
accumulate in the caller's context window. For small to medium workflows, this is fine.

**Parameters:** Skills accept arguments. A skill can receive a file path, a topic, a
length constraint, a list of flags. Arguments are injected before the model reads the
body — they are data, not natural language to be parsed.

**Anti-pattern:** Putting 400 lines of logic in one skill that does too many things.
Split responsibilities. Skills compose.

### 2.3 Subagent

A **subagent** is a skill with an isolated context window. The mechanism: add
`context: fork` to the skill's frontmatter. The runtime creates a fresh, empty context,
runs the skill inside it, and returns **only the final output** to the caller. The
forked context is then discarded.

From the caller's perspective: it sent a task, and got a result. It has no idea how
much intermediate work the subagent did — and that's the point. The caller's context
stays clean regardless of how much the subagent read, fetched, or processed.

**Design rule:** Use a subagent when the task is large enough that its intermediate
steps would pollute the caller's context, or when the task is independent enough that
its context is irrelevant to the caller.

**Cost model:** The subagent pays for its own context window. The caller pays only for
the summary returned. For large tasks (reading a 5,000-word document, auditing a whole
codebase directory, crawling multiple URLs), subagent isolation is a significant savings
for the caller.

**The key insight:** A skill and a subagent are the same file. The only code change is
two lines in the frontmatter. This is intentional — it means you can prototype a
workflow as an in-context skill, then "upgrade" it to a subagent just by adding
`context: fork`. No rewrite. No restructuring.

**Anti-pattern:** Forking for small tasks. If the skill body is 20 lines and makes two
Bash calls, forking adds overhead for no benefit. Save forking for tasks that are
genuinely large or genuinely independent.

### 2.4 Agent (definition)

An **agent** is a configured executor — a persona with a defined toolset, model, and
instructions that can be delegated to. In Claude Code, agent definitions live in
`.claude/agents/*.md`. The main Claude Code session is itself an agent; it can
delegate to sub-agents by using agent definitions.

The distinction from a skill: a skill is *instructions for the current agent to follow*.
An agent definition is *a different agent entirely*, with its own tools and constraints.
Delegating to an agent definition always runs it as a subagent (isolated context) —
the delegation is the isolation mechanism.

**Design rule:** Use an agent definition when you need a specialized executor with a
fixed toolset and persona that multiple different callers might delegate to. Think of
it as a reusable subagent template.

**Cost model:** Same as subagent — isolated context, only result returns.

### 2.5 Agent Loop

The **agent loop** is the orchestrator — typically a headless LLM invocation
(`claude --print`) running on a schedule or triggered by an event. It reads a goal,
decides which skills, subagents, or tools to invoke, observes results, and loops until
the goal is met.

The loop should contain *as little business logic as possible*. Its job is to decide and
delegate, not to do. Every piece of "doing" should be in a skill or tool — that way it's
testable, reusable, and inspectable independently of the loop.

**Design rule:** The agent loop is for automation that must run unattended. If a human
is in the loop, a skill is usually enough. When you need nightly digests, CI-triggered
analysis, or event-driven workflows, that's when you wire a loop.

**Cost model:** This is your most expensive primitive. Every loop iteration burns tokens.
Design the loop to be thin — a decision layer, not an execution layer.

---

## 3. Composition Patterns

### 3.1 The simple pipeline

```
Agent loop
  └─► calls skill A (in-context, small task)
  └─► calls skill B (in-context, small task)
  └─► writes output (tool)
```

Use when: the tasks are small, sequential, and the accumulated context from each step
is fine. The loop reads the results of each skill and acts on them.

### 3.2 The parallel subagent pattern

```
Agent loop
  ├─► subagent 1 (reads doc A, isolated)
  ├─► subagent 2 (reads doc B, isolated)
  └─► subagent 3 (reads doc C, isolated)
  └─► synthesizes results (in-context, small)
```

Use when: you have multiple independent tasks that can run in parallel, each large
enough to warrant isolation. The loop stays thin — it receives three clean summaries
and synthesizes, rather than accumulating the content of three documents.

### 3.3 The delegated agent pattern

```
Orchestrator session
  └─► delegates to agent definition "researcher"
        └─► agent "researcher" has Read + WebFetch + WebSearch tools
        └─► does its work (isolated)
        └─► returns finding
  └─► delegates to agent definition "writer"
        └─► agent "writer" has Write + Read tools only
        └─► uses findings to write output (isolated)
        └─► returns document path
```

Use when: you have specialized roles with different tool access. Separating tools by
role is a safety and reliability property — the researcher cannot accidentally write
files; the writer cannot accidentally make network requests.

### 3.4 The cron loop (fully autonomous)

```
cron (every 24h)
  └─► run-daily.sh (shell script — no LLM)
        └─► claude --print "/daily-digest"
              └─► digest-skill (in-context)
              └─► slack-post.sh (tool)
```

Use when: the workflow must run unattended on a schedule. The shell script is the
control plane — it decides timing, logging, and invocation, but contains no business
logic. The skill contains all the business logic. The Bash script is the glue.

---

## 4. Design Principles

### 4.1 Push determinism down

Any step that does not require reasoning should be a tool or a shell command. Reserve
LLM reasoning for the parts of the task that genuinely need judgment. A good test:
"Could I write this as a bash script?" If yes, do that.

### 4.2 Progressive disclosure

Never load information into context before it's needed. Skills exist in context only
as their two-line description until invoked. Reference documents should be external
files that are read only when needed, not embedded in system prompts. Dynamic context
injection (shell commands that run before the skill body is read) is the correct way to
pull in fresh environment data.

### 4.3 The context budget

Think of context as a budget. Every token loaded into context costs money on the way in
and contributes to slower, less accurate responses as the window grows. Subagents are
the mechanism for spending context budget on a sub-task without charging it to the
caller. Spend budget where it creates value; protect the caller's budget by isolating
large work.

### 4.4 Decoupled control planes

The thing that decides *when* to run (cron, event trigger, CI hook) should be completely
decoupled from the thing that decides *what* to run (the skill) and the thing that
decides *how* to deliver results (the tool). Three separate layers. Each is replaceable
without touching the others.

### 4.5 Fail visibly

An agent that silently does nothing when it can't reach a source is worse than one that
errors loudly. Skills should document their failure modes. Agent loops should log
outcomes. Delivery tools should return non-zero on failure. The system should be
operable by humans, not a black box.

---

## 5. Security Considerations

### 5.1 Tool blast radius

Skills should declare exactly which tools they need via `allowed-tools`. A skill that
only reads files should not have `Bash` access. A skill that summarizes should not have
`Write` access. Minimizing tool access minimizes the blast radius of a misbehaving or
prompt-injected skill.

### 5.2 Secrets management

Secrets (API tokens, credentials, webhook URLs) must never appear in skill bodies,
agent definitions, or any committed file. They belong in environment variables, loaded
from `.env` files that are gitignored. The pattern: a shell script `source`s the `.env`
before invoking `claude --print`; the skill receives secrets as environment variables
via the shell, never as literal text.

### 5.3 Prompt injection surface

Skills that read external content (web pages, emails, user-provided documents) are
potential prompt injection surfaces. The skill body should instruct the model to treat
fetched content as data, not as instructions. Output should be validated against a
known schema before being acted on. Subagents are a natural boundary here — the
injected content runs in an isolated context and cannot affect the caller directly.

### 5.4 Output validation

Agent loops should validate the shape of results before forwarding them downstream.
A subagent that returns malformed output should cause the loop to log an error, not
silently pass broken data to the next step.

---

## 6. Cost Model Summary

| Primitive | Context cost to caller | Latency | When to use |
|---|---|---|---|
| Tool | Zero (tools don't add to context) | Lowest | Any deterministic I/O action |
| Skill (in-context) | Body + all tool calls | Low | Small–medium reusable workflows |
| Subagent (`context: fork`) | Only the final summary | Medium (fork overhead) | Large or independent tasks |
| Agent definition | Only the final summary | Medium | Specialized executors with fixed tools |
| Agent loop | Accumulates per decision | Highest | Autonomous, unattended orchestration |

---

## 7. Migration Guide

### From: monolithic system prompt

If you have a single enormous system prompt that does everything:

1. Identify the distinct workflow steps.
2. Extract each step into a skill.
3. Wire the skills together in a thin orchestrating skill or loop.
4. Identify which steps are large enough to warrant subagent isolation.
5. Add `context: fork` to those skills.

### From: long-running Python agent

If you have a Python script that calls an LLM in a loop:

1. Extract the business logic into skills (the LLM-reasoning parts) and tools (the
   deterministic parts).
2. Replace the Python loop with `claude --print` + a skill that encodes the loop logic.
3. Keep the Python only if you need non-LLM orchestration (complex branching, database
   state, etc.).

### From: one-shot prompt

If you're sending a giant prompt once and hoping:

1. Package the prompt as a skill (it's probably already structured — give it a name).
2. Add parameters for the parts that change between invocations.
3. If the prompt causes the context to get very large, consider forking it.

---

## 8. Open Questions

1. **Skill versioning.** When a skill changes its output format, callers that depend on
   the old format break silently. We need a convention for skill versioning and a way
   to pin callers to a specific skill version.

2. **Cross-project skill sharing.** Skills currently live in project directories or
   personal home directories. There's no package registry for shared organizational
   skills. This needs to be designed.

3. **Subagent output typing.** Subagents return free-text summaries. The caller has no
   schema guarantee. We should explore structured output (JSON schemas passed at
   invocation time) so callers can validate results without natural-language parsing.

4. **Loop observability.** Agent loops currently produce log files. We have no standard
   for structured event emission (start, step-complete, error, end) or aggregated
   dashboards across loops. This is a gap for production use.

5. **Cost accounting.** We cannot currently attribute token spend to a specific skill
   invocation inside a longer session. Billing granularity is at the session level.
   For teams running many skills in parallel, per-skill cost attribution is important.

---

## 9. Appendix: Worked Example

The `daily-research-skill` project implements all four primitives:

- **Tools:** `slack-post.sh` (curl → Slack API), `WebFetch`, `WebSearch` (native tools).
- **Skill:** `daily-curated-research/SKILL.md` — the deterministic workflow that reads
  sources, filters to 24h, summarizes, and structures the report.
- **Subagent (if enabled):** Running the digest skill with `context: fork` so the
  source-reading and summarization happen in isolation, and only the report returns.
- **Agent loop:** `run-daily.sh` — a shell script that calls `claude --print` with the
  skill name, runs nightly via cron, logs to a dated file.

See: https://github.com/dacostagarcia/daily-research-skill

---

*This document is intentionally long. Its purpose is to give the document digester
demo enough content to make context isolation visibly valuable.*
