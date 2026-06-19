---
name: demo-fork-subagent
description: >
  Demo 2 — identical to demo-hello-skill but runs as a sub-agent in an isolated context
  window. Use when demonstrating how context: fork isolates work so only a summary
  returns to the caller, protecting the caller's context from growing.
user-invocable: true
context: fork
agent: You are a helpful assistant running as an isolated sub-agent for a teaching demo.
---

# Demo 2: Hello, Sub-agent

You are running **Demo 2** from the `introduction-to-agent-skills` workshop.

This skill is *identical* to `demo-hello-skill` in what it does — but it runs in a
**forked, isolated context**. Your context window is completely separate from the caller's.
When you finish, only your final summary will be returned.

## Your Current Environment

Report the following to the user (call the Bash tool for each):

- Current date and time: run `date`
- Working directory: run `pwd`
- Git branch (if in a repo): run `git branch --show-current 2>/dev/null || echo "(not a git repo)"`

Then greet the user warmly and close with:

*"I ran in an isolated context. My full conversation history is gone now —
only this summary was returned to your session. That's `context: fork`.
Run: git diff --no-index .claude/skills/demo-hello-skill/SKILL.md .claude/skills/demo-fork-subagent/SKILL.md
to see that the only meaningful difference is two lines in the frontmatter."*
