---
name: introduction-to-agent-skills
description: >
  Guided tour of the Claude Code agentic taxonomy: skills, subagents, agents, and
  agent loops — explained through a single live example (the document digester) expressed
  at each level. Use when introducing or teaching how the four primitives differ and
  compose. Runs in the caller's context (it's a skill about skills).
user-invocable: true
---

# Introduction to Agent Skills

*You just invoked a skill that teaches you about skills.*

---

## The taxonomy — four primitives, one diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AGENT LOOP (the orchestrator)                    │
│      headless `claude --print` · decides what to invoke · repeats  │
│                      🧠 most expensive                               │
│                                                                     │
│    ┌──────────────────────┐    ┌──────────────────────────────┐     │
│    │        SKILL         │    │   SUBAGENT / AGENT           │     │
│    │  runs in YOUR context│    │  isolated context window     │     │
│    │  SKILL.md, no fork   │    │  SKILL.md + context: fork    │     │
│    │  💚 cheap to invoke   │    │  or .claude/agents/*.md      │     │
│    │                      │    │  💛 pays its own context      │     │
│    └──────────────────────┘    └──────────────────────────────┘     │
│                         calls                                       │
│    ┌───────────────────────────────────────────────────────────┐    │
│    │              TOOLS / MCP                                  │    │
│    │  Read, Bash, WebFetch, WebSearch, Slack MCP, …            │    │
│    │  deterministic I/O · no reasoning · 💚 very cheap          │    │
│    └───────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

| Primitive | What it is | How you get it |
|---|---|---|
| **Skill** | Reusable instructions. In the **caller's** context. Zero cost until invoked. | `SKILL.md` |
| **Subagent** | Isolated context. Only the result returns. Caller stays clean. | `SKILL.md` + `context: fork` |
| **Agent** | Named, isolated executor. Fixed tools + model. Delegated by orchestrators. | `.claude/agents/NAME.md` |
| **Agent loop** | The orchestrator. Headless. Repeats. Decides what to call. | `claude --print` in a shell script |

---

## The single example: a document digester

This repo teaches the taxonomy using **one task** expressed four ways.
The task: read a long document (`sample-doc.md`) and return a short digest.

As you run each expression below, notice what changes — and what *doesn't*.

---

### Expression 1 — Skill (in-context)

```
/digest-skill sample-doc.md "key risks" short
```

The skill body loads into **your** context. Notice what this single file demonstrates:
- `$1 = sample-doc.md` — positional param (the path)
- `$focus = "key risks"` — named param from the `arguments:` block
- `$length = short` — named param controlling output format
- `` !`wc -w "$1"` `` — word count injected *before* the model read anything. No tool call.
- `allowed-tools: [Read, Bash]` — blast radius locked in the frontmatter.

After it runs: your context window grew by the size of `sample-doc.md` + the reasoning +
the digest. Everything lived here. That's the in-context cost — the baseline to beat.

---

### Expression 2 — Subagent (`context: fork`)

```
/digest-subagent sample-doc.md "key risks" short
```

Exactly the same task — but the document is read in an **isolated context**. Only the
digest returns. Your context does not grow.

Then run the diff — this is the talk's key moment:

```bash
git diff --no-index \
  .claude/skills/digest-skill/SKILL.md \
  .claude/skills/digest-subagent/SKILL.md
```

The diff is two lines in the frontmatter. That's the entire lesson between a skill and
a subagent.

---

### Expression 3 — Agent definition

Ask Claude directly:

> "Use the digester agent to summarize sample-doc.md, focusing on security considerations,
> in a short digest."

Claude will delegate to `.claude/agents/digester.md` via the Agent tool. Open that file
in a split pane while it runs and point at:
- `model: claude-haiku-4-5-20251001` — cheaper model, set in the definition. Every caller
  that delegates to this agent gets haiku. The caller doesn't choose.
- `tools: [Read, Bash]` — the agent definition syntax for tool restriction (vs `allowed-tools`
  in skills — same purpose, different key name).
- No `context: fork` — it's implicit. Delegation always creates isolation.

The key distinction from a subagent skill: this is a *thing* (a named, stable executor),
not a *relationship* (this skill, run isolated, once). Any orchestrator can delegate to it.

---

### Expression 4 — Agent loop

```bash
bash digest-all.sh --dry-run
bash digest-all.sh
```

`digest-all.sh` is the orchestrator. It loops over `docs/*.md`, calls
`claude --print "/digest-subagent <file>"` for each, and writes results to `digests/`.

Notice what the script contains: iteration logic and invocation. No business logic.
That lives in `digest-subagent`. The loop's only job is to decide and repeat.

---

## The two "aha"s

**1. Skill → Subagent = one line.**
`context: fork` in the frontmatter. Same SKILL.md body. Completely different
execution model. You can prototype as a skill, then upgrade to a subagent by adding
one line. No rewrite needed.

**2. Subagent vs Agent definition.**
Both are isolated. The difference: a subagent is a *relationship* (this skill runs
isolated); an agent definition is a *thing* (a named executor any orchestrator can
delegate to, with fixed tools and model). If multiple callers need the same isolated
executor, name it as an agent.

---

## Go deeper

- **Full taxonomy breakdown:** `reference/taxonomy.md` — cost/context trade-offs, when
  to reach for each, anti-patterns, all illustrated with the digest example.
- **Every frontmatter option:** `reference/frontmatter.md` — `context: fork`, `agent:`,
  `allowed-tools`, `arguments:`, dynamic injection, string substitutions.
- **Production example:** https://github.com/dacostagarcia/daily-research-skill — all
  four primitives working together in a real nightly automation.
