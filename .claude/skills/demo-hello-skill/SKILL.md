---
name: demo-hello-skill
description: >
  Demo 1 — the simplest possible skill. Greets the user and reports the current
  working environment. Use when demonstrating how a basic skill runs in-context,
  how progressive disclosure works, and how zero tokens are consumed until invocation.
user-invocable: true
---

# Demo 1: Hello, Skill

You are running **Demo 1** from the `introduction-to-agent-skills` workshop.

Teaching points you should call out after this runs:

1. **Progressive disclosure** — only the `name` and `description` above sat in context
   before this moment. The entire body just loaded when you typed `/demo-hello-skill`.

2. **In-context execution** — this skill runs inside *your* context window. Everything
   below is now part of your conversation history. Compare with `/demo-fork-subagent`.

3. **Deterministic instructions** — the skill body is just structured text. The model
   reads it and follows it. No application code, no build step, no deploy.

---

## Your Current Environment

Report the following to the user (just call the Bash tool for each):

- Current date and time: run `date`
- Working directory: run `pwd`
- Git branch (if in a repo): run `git branch --show-current 2>/dev/null || echo "(not a git repo)"`

Then greet the user warmly and tell them: *"This output appeared directly in your context.
That's the difference between a skill and a sub-agent — compare with /demo-fork-subagent."*
