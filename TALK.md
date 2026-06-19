# Talk: Introduction to Agent Skills

**Audience:** Engineers who use or build with Claude Code.
**Format:** 30–45 min talk + live demo. Hands-on encouraged — audience can clone and follow along.
**Goal:** Leave with a mental model for *when to use each primitive* and muscle memory from
seeing them run live.

---

## The thesis (one line)

> Treat LLM reasoning as expensive compute. Push determinism into skills and tools.
> Save the agent loop for judgment.

---

## The four-boxes diagram

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

---

## Talk structure

### Part 1 — The problem (5 min)

> "You want to automate something with Claude. You could just dump a giant prompt in a
> system message and hope. Or you could understand the four primitives and design it right."

- What goes wrong when you treat everything as "just talk to the model":
  - Context bloat (expensive + slow)
  - Non-determinism where you want reliability
  - No reuse — every task reinvents the wheel
- The answer: a vocabulary. Four primitives. One mental model.

### Part 2 — The primitives (15 min)

Walk the four-boxes diagram top-down. For each, state:
1. What it is (one sentence)
2. Cost model (cheap / pays its own / expensive)
3. The single decision rule (when to reach for it)

**Tools / MCP:**
- "The hands. No reasoning. If `curl` works, don't use an LLM."
- Demo: `bash slack-post.sh "hello from the talk"` — posts to Slack, zero reasoning.

**Skill:**
- "Packaged instructions. Zero tokens until invoked — progressive disclosure."
- Demo: `/introduction-to-agent-skills` — you just invoked a skill *about* skills.
- Show: in the skills picker, all skills are visible but only name+description loaded.

**Sub-agent (`context: fork`):**
- "Same SKILL.md. One line added. Isolated context. Only a summary returns."
- Demo: `/demo-fork-subagent` — same task as Demo 1, but isolated.
- Live diff: `git diff --no-index .claude/skills/demo-hello-skill/SKILL.md .claude/skills/demo-fork-subagent/SKILL.md`
- Point at the diff: "That's the lesson. One line."

**Agent loop:**
- "The orchestrator. Headless. Runs on a schedule. Calls skills and tools. Expensive — design
  it to be the decider, not the worker."
- Show: `run-daily.sh` from daily-research-skill — a 30-line shell script that calls
  `claude --print "/daily-curated-research"` and logs the result.

### Part 3 — Live demos (10 min)

Run in this order — each one builds on the previous:

```bash
# Demo 1: basic skill (in-context)
/demo-hello-skill

# Demo 2: sub-agent (isolated) — then diff
/demo-fork-subagent
git diff --no-index \
  .claude/skills/demo-hello-skill/SKILL.md \
  .claude/skills/demo-fork-subagent/SKILL.md

# Demo 3: dynamic context injection
/demo-dynamic-context YourName

# Demo 4: the teaching skill itself (meta-moment)
/introduction-to-agent-skills
```

### Part 4 — The real-world example (10 min)

Open `daily-research-skill/` side-by-side.

Show the composition:
```
cron → run-daily.sh → claude --print "/daily-curated-research" → WebFetch/WebSearch → Bash → Slack
```

Point out each primitive in its natural habitat:
- `run-daily.sh` = control plane (no LLM)
- `claude --print` = agent loop (the judge)
- `daily-curated-research/SKILL.md` = the skill (the worker, deterministic logic)
- `slack-post.sh` = the tool (pure I/O)
- `.mcp.json` = MCP tool declarations

Ask: *"Where would you add a sub-agent if this skill got too large?"*
Answer: change `context: fork` in the SKILL.md. One line. Done.

### Part 5 — Hands-on (optional, 10 min)

```bash
# Clone the repo
git clone https://github.com/dacostagarcia/introduction-to-agent-skills
cd introduction-to-agent-skills

# Try the demos
/demo-hello-skill
/demo-fork-subagent
/demo-dynamic-context YourName

# Modify demo-hello-skill to do something else
# Then diff with demo-fork-subagent to see what context: fork adds
```

---

## Key takeaways (write these on the board)

1. **Tool** = deterministic I/O, no LLM, cheapest.
2. **Skill** = packaged instructions, in-context, zero cost until invoked.
3. **Sub-agent** = skill + `context: fork`, isolated, only summary returns.
4. **Agent loop** = orchestrator, headless, most expensive — use it to *decide*, not *do*.
5. **The rule:** push determinism down; save reasoning for what only reasoning can do.

---

## Q&A hooks

- *"When do you actually need an agent loop vs just running a skill manually?"*
  When it must run unattended, on a schedule, without a human in the loop.
- *"Can sub-agents call other sub-agents?"*
  Yes — nesting is possible. Be careful of cost explosion.
- *"Can I use MCP tools in a skill?"*
  Yes — any MCP server declared in `.mcp.json` is available unless excluded by `disallowed-tools`.
- *"What's the difference between `allowed-tools` in the skill vs in the headless run?"*
  Both apply — the intersection is what actually runs. Headless `--allowedTools` is the outer
  permission boundary; the skill's `allowed-tools` is the inner contract.

---

## Resources

- This repo: https://github.com/dacostagarcia/introduction-to-agent-skills
- Real-world example: https://github.com/dacostagarcia/daily-research-skill
- Anthropic skills docs: https://code.claude.ai/docs/en/skills
- DeepLearning.AI "Agent Skills with Anthropic" course
