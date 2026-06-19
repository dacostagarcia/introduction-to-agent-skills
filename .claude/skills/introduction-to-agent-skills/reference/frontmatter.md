# SKILL.md Frontmatter Reference

*Every Claude Code skill frontmatter field, annotated. Examples use the digest skill.*

*This file is not loaded until you open it — progressive disclosure.*

---

## Required fields

```yaml
name: digest-skill
```
**`name`** — the slash-command trigger (`/digest-skill`). kebab-case. Gerund naming
for action skills (`digesting-document`, `posting-digest`). Must be unique across
all skill directories Claude Code scans.

```yaml
description: >
  Reads a local markdown document and returns a short digest. Accepts a file path,
  an optional focus topic, and an optional length. Use when you want to summarize
  a document and keep the result in the current session.
```
**`description`** — the *only thing in context* before invocation (progressive
disclosure). Write in third person. Include "Use when…" — it tells the model when to
invoke automatically. Keep under 3 sentences; detail goes in the body.

---

## Invocation control

```yaml
user-invocable: true
```
**`user-invocable`** — shows the skill in `/help` and the picker. Omit or `false` for
skills intended to be called only by other skills/agents, never directly by the user.

```yaml
argument-hint: "<path> [focus] [length: short|medium|long]"
```
**`argument-hint`** — hint text shown next to the skill name in the picker. Tells the
user what to type. Cosmetic only; does not enforce any schema.

```yaml
arguments:
  focus:
    description: Topic or angle to emphasize. Defaults to balanced overview.
    required: false
  length:
    description: "short (3–5 bullets), medium (1 paragraph), long (3 paragraphs)."
    required: false
```
**`arguments`** — named argument definitions. Each key is accessible as `$focus`,
`$length`, etc. in the body via string substitution. Use when you want self-documented,
typed params instead of parsing raw `$ARGUMENTS`.

---

## Context + isolation

```yaml
context: fork
```
**`context: fork`** — run this skill as a subagent: isolated context window, only
the final output returns to the caller. **This is the one line that separates a skill
from a subagent.** Without this, the skill runs in the caller's context. Add it and
the runtime creates a fresh context, runs there, and discards it.

```yaml
agent: >
  You are a focused document digester running in an isolated context. Your only job
  is to read the document, produce the digest, and return it cleanly.
```
**`agent`** — the system prompt for the forked subagent. Only meaningful when
`context: fork` is set. Gives the isolated execution its persona and core constraints.
Keep it tight — the body has the detailed instructions.

---

## Tool access (blast radius control)

```yaml
allowed-tools:
  - Read
  - Bash
```
**`allowed-tools`** — whitelist. This skill can only call `Read` and `Bash`. If it
tried to call `WebFetch` or `Write`, the call would be blocked. Use to enforce least
privilege — a read-only analysis skill should not have `Write` access.

```yaml
disallowed-tools:
  - Bash
```
**`disallowed-tools`** — blacklist. Block specific tools while leaving everything else
open. Use when you want to say "everything the session allows, except `Bash`."

---

## Model + effort

```yaml
model: claude-haiku-4-5-20251001
```
**`model`** — override the model for this skill/subagent. Omit to inherit the session
model. Use `haiku` for cheap, fast, mechanical tasks (digesting is a good example —
it's careful reading, not heavy reasoning). Reserve `opus` for the hardest judgment
steps. The `digester` agent definition uses `haiku` explicitly.

```yaml
effort: low
```
**`effort`** — reasoning effort: `low`, `medium`, `high`, `xhigh`, `max`. Omit to
inherit. `low` for deterministic/mechanical steps; raise for complex reasoning.
Directly controls token spend per invocation.

---

## Other fields

```yaml
disable-model-invocation: true
```
**`disable-model-invocation`** — when `true`, the skill body runs as raw text without
LLM processing. Rare — useful for skills that are pure shell scripts you want to
package as invocable by name, without any model interpretation.

---

## Agent definition fields (`.claude/agents/NAME.md`)

Agent definitions share most fields with skills. Unique to agent definitions:

```yaml
tools:
  - Read
  - Bash
```
**`tools`** — the agent's allowed tool list, set at definition time (not call time).
Every caller that delegates to this agent gets these tools — no more, no less.

Agent definitions always run isolated (always behave as subagents). There is no
`context: fork` needed — it's implicit.

---

## Dynamic context injection (body syntax)

Not frontmatter — these work in the SKILL.md body:

```
!`wc -w "$1" 2>/dev/null | awk '{print $1}'`
```
**`` !`command` ``** — shell command executed **before the model reads the file**.
Output is substituted inline. In `digest-skill`, this injects the document's word
count so the model knows the document size without spending a tool call to find it.
Use for: current date, git state, file sizes, environment variables.

```
$ARGUMENTS        # everything after the skill name
$1  $2  $3        # positional args split on whitespace
$focus  $length   # named args from the arguments: block
${CLAUDE_SKILL_DIR}    # absolute path to this skill's directory
${CLAUDE_SESSION_ID}   # current session ID (useful for logging)
${CLAUDE_EFFORT}       # resolved effort level for this invocation
```
**String substitutions** — replaced before the model reads the body. `$1` is the
first word after `/digest-skill`; `$focus` is the named `focus` argument. All
substitution happens deterministically at load time — the model never has to parse
arguments from natural language.

---

## Skill locations (precedence, highest first)

1. `.claude/skills/` in the current project directory
2. `~/.claude/skills/` in the user's home directory (personal, available in all sessions)
3. Skills provided by MCP skill servers

Project skills override personal skills of the same name.

Agent definitions follow the same pattern:
1. `.claude/agents/` in the current project
2. `~/.claude/agents/` in the user's home

---

## Minimal valid SKILL.md

```yaml
---
name: hello-world
description: Says hello. Use when testing skill invocation.
---

Say hello and report the current date by running `date` via Bash.
```

Two required frontmatter fields, one instruction. Everything else is optional
progressive enhancement.
