---
name: demo-dynamic-context
description: >
  Demo 3 — shows dynamic context injection: shell commands run before the skill body
  loads, so the model receives live environment data without having to fetch it.
  Also demonstrates $ARGUMENTS substitution. Use when teaching how skills can be
  parameterized and pre-populated with deterministic context before any LLM reasoning.
user-invocable: true
argument-hint: "[your name]"
---

# Demo 3: Dynamic Context Injection

You are running **Demo 3** from the `introduction-to-agent-skills` workshop.

## Live context injected before you read this:

- **Invoked by:** $1 (from `$ARGUMENTS` — the argument you passed on invocation)
- **Date:** !`date`
- **Working directory:** !`pwd`
- **Git branch:** !`git branch --show-current 2>/dev/null || echo "(not a git repo)"`
- **Recent files:** !`ls -1t | head -5`

---

## Teaching points to explain to the user

1. **`!`command`` syntax** — any backtick expression prefixed with `!` in the frontmatter
   or body is executed by the shell *before* the model reads this file. The output is
   substituted inline. The model never had to call Bash to get this information — it
   arrived as context, deterministically and cheaply.

2. **`$1` / `$ARGUMENTS`** — the argument the user typed after `/demo-dynamic-context`
   is substituted directly into the skill body. No prompt engineering needed; the user's
   input is injected as data, not parsed from natural language.

3. **Why this matters** — dynamic injection lets you build skills that are always
   fresh (current date, current branch, current file list) without spending tokens on
   tool calls to gather that context. Push determinism into the shell; save reasoning
   for the parts that need it.

---

Now greet `$1` by name, summarize the injected context above, and confirm which git
branch and directory we're in.
