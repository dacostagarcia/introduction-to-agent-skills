# introduction-to-agent-skills

A teaching repo for the talk **"Introduction to Agent Skills"** — a hands-on tour of
the four primitives in Claude Code agentic systems: tools/MCP, skills, sub-agents, and
agent loops.

The repo *is* the demo. Every file here is a skill you can invoke live.

---

## The four primitives at a glance

| Primitive | What it is | Cost | When to use |
|---|---|---|---|
| **Tool / MCP** | Deterministic I/O (Bash, WebFetch, Slack, GitHub…) | Cheapest | Bounded actions with no reasoning needed |
| **Skill** | Packaged instructions in a SKILL.md. Zero tokens until invoked. | Cheap | Reusable, deterministic workflows |
| **Sub-agent** | Same SKILL.md + `context: fork`. Isolated context. | Pays its own | Large/independent tasks that would bloat the caller |
| **Agent loop** | Headless `claude --print` on a schedule. The orchestrator. | Expensive | Autonomous, unattended workflows |

> The single best "aha": **a skill and a sub-agent are the same file. The only difference
> is `context: fork` in the frontmatter.**

---

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- A project where Claude Code is running (or clone this repo and `claude` inside it)

---

## Quick start

```bash
git clone https://github.com/dacostagarcia/introduction-to-agent-skills
cd introduction-to-agent-skills
claude  # open Claude Code in this directory
```

Then in Claude Code:

```
# Start the guided tour
/introduction-to-agent-skills

# Run each demo in order
/demo-hello-skill
/demo-fork-subagent
/demo-dynamic-context YourName
```

---

## Skills in this repo

| Skill | What it demonstrates |
|---|---|
| `/introduction-to-agent-skills` | The entry-point tour — explains all four primitives and guides you through the demos |
| `/demo-hello-skill` | A minimal skill running in-context (Demo 1) |
| `/demo-fork-subagent` | Same skill + `context: fork` → isolated sub-agent (Demo 2) |
| `/demo-dynamic-context` | Dynamic context injection with `` !`cmd` `` and `$ARGUMENTS` (Demo 3) |

---

## The live diff (the talk's key moment)

```bash
git diff --no-index \
  .claude/skills/demo-hello-skill/SKILL.md \
  .claude/skills/demo-fork-subagent/SKILL.md
```

This diff shows exactly what separates a skill from a sub-agent: two lines of frontmatter.

---

## Go deeper

- **`reference/concepts.md`** — full cost/context trade-off breakdown and anti-patterns
  (inside `.claude/skills/introduction-to-agent-skills/reference/`)
- **`reference/frontmatter.md`** — every SKILL.md frontmatter field explained
- **`TALK.md`** — speaker narrative, demo running order, Q&A hooks

---

## Real-world example

This repo teaches the primitives in isolation. To see all four working together in a
production project:

**[daily-research-skill](https://github.com/dacostagarcia/daily-research-skill)** —
an autonomous daily research digest. Uses a skill (the deterministic workflow), MCP/Bash
tools (Slack delivery), and a headless agent loop (cron → `claude --print`) to read
the web every 24 hours and post to a private Slack channel.

---

## Installing skills globally

To use these skills in any project (not just this repo), copy the skills directory to
your personal skills folder:

```bash
cp -r .claude/skills/* ~/.claude/skills/
```

Skills in `~/.claude/skills/` are available in every Claude Code session.

---

## License

MIT. Clone it, fork it, use it in your talk.
