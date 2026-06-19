# Talk: Introduction to Agent Skills

**Audience:** Engineers who use or build with Claude Code.  
**Format:** 30–45 min talk + live demos. Clone the repo and follow along.  
**Goal:** Leave with a precise mental model of the four primitives and muscle memory from
running them live.

---

## Thesis (write this on the board)

> One task. Four expressions. Only the level changes.

The whole talk is a proof of that claim. The task is always "digest a document."
The four expressions are: skill, subagent, agent definition, agent loop.

---

## The four primitives — one diagram

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
│    └───────────────────────────────────────────────────────────┘    │
│              TOOLS / MCP: Read, Bash, WebFetch, Slack MCP, …       │
│              deterministic I/O · no reasoning · 💚 very cheap       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Talk structure

### Part 1 — The problem (5 min)

> "Most things people call 'agents' are just badly packaged prompts. We need a vocabulary."

The four failure modes:
- **Context bloat** — everything ends up in one giant context; slow, expensive, degrades.
- **Non-determinism where you want reliability** — LLM decides to `curl` when bash would do.
- **Zero reuse** — same "summarize this" logic in 7 places.
- **Untestable** — a 400-line system prompt isn't a unit.

The solution: four primitive types, each with a clear definition and a decision rule.

### Part 2 — The taxonomy (15 min)

Walk through each primitive with its one-liner, cost model, and decision rule.
Use the table in `reference/taxonomy.md` as the backbone.

**Tools:** "The hands. Deterministic I/O. If bash can do it, don't use an LLM."

**Skill:** "Packaged instructions. Zero tokens until invoked — progressive disclosure.
Runs in your context. The baseline."

**Subagent:** "Same SKILL.md. One line added. Isolated context. Only the result returns.
Your context stays clean regardless of how much work the subagent did."

**Agent definition:** "A named, isolated executor with fixed tools and model. Any
orchestrator can delegate to it. It's a thing, not a relationship."

**Agent loop:** "The orchestrator. Headless. Repeats. Its job is to decide and delegate —
not to do the work itself."

### Part 3 — The live demos (15 min)

Run in order. Each one builds on the previous.

**Demo 1 — Skill**
```
/digest-skill sample-doc.md "key risks" short
```
After: "Notice your context just grew. The whole document is in your history now.
That's the baseline. Now let's isolate."

**Demo 2 — Subagent + the diff**
```
/digest-subagent sample-doc.md "key risks" short
```
After: "Same task. Same output. Your context didn't grow. Now the reveal:"
```bash
git diff --no-index \
  .claude/skills/digest-skill/SKILL.md \
  .claude/skills/digest-subagent/SKILL.md
```
Point at the diff: **"`context: fork` and `agent:`. Two lines. That's the entire
lesson between a skill and a subagent."** Let it land.

**Demo 3 — Agent definition**
Say to Claude in the session:
> "Use the digester agent to summarize sample-doc.md — focus on open questions, short."

Watch Claude delegate via the Agent tool. Point out:
- The model used is `haiku` — set in the agent definition, not here.
- Tools are `Read` + `Bash` only — the agent can't fetch URLs or write files.
- It's always isolated — the definition implies the fork.

Open `.claude/agents/digester.md` in a split pane and walk the frontmatter.

**Demo 4 — Agent loop**
```bash
bash digest-all.sh --dry-run   # show the plan
bash digest-all.sh             # run it
cat digests/agentic-patterns-digest.md
```
Open `digest-all.sh` side-by-side. Point at the content: "There is no business logic
here. The loop decides *what* to run and *repeats*. The skill does the work."

### Part 4 — The production capstone (5 min)

Open `daily-research-skill` (https://github.com/dacostagarcia/daily-research-skill).

Show the composition — all four primitives working in production:

```
cron → run-daily.sh → claude --print "/daily-curated-research"
                          ↓
                   reads sources.yaml (Read tool)
                   fetches sources (WebFetch/WebSearch)
                   writes /tmp/digest.txt (Write tool)
                   bash slack-post.sh < /tmp/digest.txt (Bash → curl → Slack API)
```

Point at each layer: "Tool. Skill. Agent loop. Bot token in `.env`, never committed."

Ask: **"Where would you add a subagent if reading sources bloated the context?"**
Answer: add `context: fork` to the skill. One line. That's always the answer.

### Part 5 — Hands-on (optional, 10 min)

```bash
git clone https://github.com/dacostagarcia/introduction-to-agent-skills
cd introduction-to-agent-skills
claude

# In Claude Code:
/introduction-to-agent-skills
/digest-skill sample-doc.md
/digest-subagent sample-doc.md
# Then diff them
```

Challenge: "Add a third named param to `digest-skill` — `format` (bullets/prose/table).
Then propagate it to `digest-subagent`. Count the lines changed."

---

## The two "aha"s — say these twice

**1.** "A skill and a subagent are the same file. `context: fork` is the entire difference."

**2.** "The agent loop contains no business logic. Its job is to decide and repeat.
All the 'how' lives in skills."

---

## Q&A hooks

**"When do I actually need an agent loop vs running a skill manually?"**  
When it must run unattended on a schedule. If a human triggers it, a skill is usually enough.

**"Can subagents call other subagents?"**  
Yes — but nested forking compounds cost quickly. Use it deliberately.

**"Can I use MCP tools inside a skill?"**  
Yes — any MCP server in `.mcp.json` is available unless excluded by `disallowed-tools`.

**"What's the difference between `allowed-tools` in the skill vs in the headless run?"**  
Both apply. Headless `--allowedTools` is the outer permission boundary; the skill's
`allowed-tools` is the inner contract. The intersection runs.

**"Can I pass structured data to a subagent, not just file paths?"**  
Yes — `$ARGUMENTS` captures everything after the skill name as a string. For structured
data, write a temp file and pass the path, or use `arguments:` named params.

**"How do I debug a subagent? I can't see its context."**  
Add a `Write` tool call inside the subagent body to log intermediate state to a file.
Or temporarily remove `context: fork` and run as an in-context skill to see everything.

---

## Resources

- This repo: https://github.com/dacostagarcia/introduction-to-agent-skills
- Production example: https://github.com/dacostagarcia/daily-research-skill
- Claude Code skills docs: https://code.claude.ai/docs/en/skills
- DeepLearning.AI "Agent Skills with Anthropic" course
