# SKILL.md Frontmatter Reference

*Every field available in Claude Code skill frontmatter, with one-line explanations.*

*Not loaded until you open this file — progressive disclosure in action.*

---

## Required fields

```yaml
name: my-skill
```
**`name`** — the slash-command trigger (`/my-skill`). Use kebab-case. Gerund naming
recommended for action skills (`fetching-sources`, `posting-digest`). Must be unique
within the skills directories Claude Code scans.

```yaml
description: >
  Fetches the daily news digest and posts it to Slack. Use when you want to run
  the daily research summary or test the automated pipeline.
```
**`description`** — the only thing loaded into context *until the skill is invoked*.
Write in third person. Include a "Use when…" clause — it helps the model decide when
to invoke the skill automatically. Keep it under 3 sentences; depth goes in the body.

---

## Invocation control

```yaml
user-invocable: true
```
**`user-invocable`** — when `true`, the skill appears in `/help` and the skill picker.
Omit or set `false` for skills meant to be called only by other skills/agents, not by
users directly.

```yaml
argument-hint: "[topic] [date]"
```
**`argument-hint`** — placeholder text shown next to the skill name in the picker.
Tells the user what arguments to pass. Cosmetic only.

```yaml
arguments:
  topic:
    description: The research topic to focus on.
    required: false
```
**`arguments`** — structured argument definitions. Each key maps to a named argument
accessible as `$name` in the body. Use when you want typed, documented parameters
instead of raw `$ARGUMENTS`.

---

## Context management

```yaml
context: fork
```
**`context: fork`** — run this skill in an isolated sub-agent context. Only a summary
returns to the caller. Use when the task is large, independent, or would bloat the
caller's context window. Without this field, the skill runs in the caller's context.

```yaml
agent: You are a focused research assistant for this isolated task.
```
**`agent`** — the system prompt for the forked sub-agent. Only meaningful when
`context: fork` is set. Gives the isolated agent its persona and constraints.

---

## Tool access

```yaml
allowed-tools:
  - WebFetch
  - WebSearch
  - Bash
  - Read
  - Write
```
**`allowed-tools`** — whitelist the tools this skill can use. The skill cannot call
any tool not in this list. Use to lock down blast radius (e.g. a read-only analysis
skill should not have `Write` or `Bash`).

```yaml
disallowed-tools:
  - Bash
```
**`disallowed-tools`** — blacklist specific tools (complement to `allowed-tools`).
Useful when you want everything *except* a dangerous tool.

---

## Model and effort

```yaml
model: claude-sonnet-4-6
```
**`model`** — override which Claude model runs this skill. Omit to inherit the
session default. Use `haiku` for cheap, fast, repetitive sub-tasks; `opus` for the
hardest reasoning steps. Default: the session model.

```yaml
effort: low
```
**`effort`** — reasoning effort: `low`, `medium`, `high`, `xhigh`, `max`. Omit to
inherit. Use `low` for deterministic/mechanical skills; raise only for complex
reasoning. Directly controls token spend.

---

## Meta

```yaml
disable-model-invocation: true
```
**`disable-model-invocation`** — when `true`, the skill body runs as-is without any
LLM processing. Use for pure shell scripts or configuration files you want packaged
as a skill but don't need the model to interpret. Rare.

---

## Dynamic context injection (body syntax)

These aren't frontmatter fields — they work in the SKILL.md body:

```
!`date`
```
**`` !`command` ``** — executes the shell command *before the model reads the file*.
Output is substituted inline. Use to inject live context (date, env vars, file lists,
git state) deterministically, without spending tokens on Bash tool calls.

```
$ARGUMENTS
$1  $2  $3
$name  (if arguments: block defined)
${CLAUDE_SKILL_DIR}
${CLAUDE_SESSION_ID}
${CLAUDE_EFFORT}
```
**String substitutions** — replaced before the model reads the body:
- `$ARGUMENTS` — everything the user typed after the skill name
- `$1`, `$2`, … — positional arguments split on whitespace
- `$name` — named argument from the `arguments:` block
- `${CLAUDE_SKILL_DIR}` — absolute path to this skill's directory
- `${CLAUDE_SESSION_ID}` — current session ID (useful for logging)
- `${CLAUDE_EFFORT}` — the resolved effort level for this invocation

---

## Skill locations (precedence, highest first)

1. `.claude/skills/` in the current project directory
2. `~/.claude/skills/` in the user's home directory (personal, cross-project)
3. Skills installed via MCP skill servers

Project skills override personal skills of the same name.

---

## Minimal working skill

```yaml
---
name: hello-world
description: Says hello. Use when testing skill invocation.
---

Say hello and report the current date (run `date` via Bash).
```

That's it. Two required fields in frontmatter, one instruction in the body.
Everything else is optional progressive enhancement.
