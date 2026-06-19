---
name: introduction-to-agent-skills
description: >
  Teaches the four primitives of Claude Code agentic systems — tools/MCP, skills,
  sub-agents, and agent loops — and how they compose. Use when introducing or teaching
  how Claude Code skills, sub-agents, agents, and MCP tools differ, when to use each,
  and how they fit together in a real project.
user-invocable: true
---

# Introduction to Agent Skills

Welcome. This skill *is* the lesson — you're looking at a SKILL.md being invoked right now.

---

## The Four Primitives

Every Claude Code agentic system is built from exactly four building blocks.
If you understand these four things and when to reach for each, you understand the whole model.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AGENT LOOP (orchestrator)                        │
│         headless `claude --print` · decides what to call            │
│                      🧠  expensive                                   │
│                                                                     │
│    ┌──────────────────────┐    ┌──────────────────────────────┐     │
│    │       SKILL          │    │         SUB-AGENT            │     │
│    │  (caller's context)  │    │  (forked, isolated context)  │     │
│    │  SKILL.md, no fork   │    │  SKILL.md + context: fork    │     │
│    │  💚 cheap to invoke   │    │  💛 pays its own context      │     │
│    └──────────────────────┘    └──────────────────────────────┘     │
│                         calls                                       │
│    ┌───────────────────────────────────────────────────────────┐    │
│    │              TOOLS / MCP                                  │    │
│    │  WebFetch, Bash, WebSearch, Slack MCP, GitHub MCP, …      │    │
│    │  deterministic I/O — no reasoning — 💚 very cheap          │    │
│    └───────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### 1. Tools / MCP
The **hands** of the system. Deterministic I/O: fetch a URL, run a shell command, post to
Slack, query a database. No reasoning happens here — they just execute.

> *Use tools when you need a specific, bounded action. Never use an LLM where a `curl` will do.*

### 2. Skill
A packaged set of instructions (this file). **Zero tokens sit in context until you invoke it**
— only `name` + `description` are ever loaded by the caller, so skills don't bloat your
context window just by existing. When invoked, the body loads and runs **in the caller's context**.

> *Use a skill when you have deterministic logic you want to reuse and invoke by name.*

### 3. Sub-agent
**Exactly the same SKILL.md** — but with `context: fork` in the frontmatter. That one line
changes everything: the work runs in an **isolated context window**. Only a summary returns to
the caller. Your context stays clean regardless of how much the sub-agent does.

> *Use a sub-agent when the work is large, independent, or would pollute the caller's context.*

### 4. Agent Loop
A control-plane LLM running headless (`claude --print`) on a schedule (cron / launchd).
It reads instructions, decides which skills and tools to call, and orchestrates the whole
workflow autonomously.

> *Use an agent loop for automation that must run unattended — the orchestrator, not the worker.*

---

## Live Demos — Run These Now

Three skills in this repo illustrate the primitives. Run each in order:

**Demo 1 — Skill (in-context):**
```
/demo-hello-skill
```
Notice: the output appears inline. The work happened in *your* context window.

**Demo 2 — Sub-agent (forked, isolated):**
```
/demo-fork-subagent
```
Notice: you get back a summary. The work happened in a *separate* context that is now gone.
Then run:
```
git diff --no-index .claude/skills/demo-hello-skill/SKILL.md .claude/skills/demo-fork-subagent/SKILL.md
```
The diff is one meaningful line: `context: fork`. That's the entire lesson.

**Demo 3 — Dynamic context injection:**
```
/demo-dynamic-context Your Name Here
```
Notice: the skill body was populated with live shell output (date, pwd, git branch) *before*
the model read it. `$1` was replaced with your argument. The model didn't have to go look
for any of it — it was injected deterministically.

---

## The Real-World Example

All four primitives working together in production:

```
daily-research-skill/
  .claude/skills/daily-curated-research/SKILL.md  ← the skill (and sub-agent if forked)
  slack-post.sh + .mcp.json                       ← the tools
  run-daily.sh                                    ← the agent loop (headless claude --print)
```

See: https://github.com/dacostagarcia/daily-research-skill

---

## Go Deeper

- **Concepts in detail:** See `reference/concepts.md` in this skill's directory for the
  full cost/context trade-off breakdown and anti-patterns.
- **All frontmatter options:** See `reference/frontmatter.md` for every SKILL.md field
  with one-line explanations and when to use each.

---

*Medium = message: you just ran a skill that teaches you about skills.*
