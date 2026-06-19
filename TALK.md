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
│    │              TOOLS / MCP                                  │    │
│    │  Read, Bash, WebFetch, WebSearch, Slack MCP, …            │    │
│    │  deterministic I/O · no reasoning · 💚 very cheap          │    │
│    └───────────────────────────────────────────────────────────┘    │
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
- Point at the `!` injection in `digest-skill`: `` !`wc -w "$1"` `` runs before the model
  reads the file, injecting the word count as data — zero tokens, zero tool calls.

**Skill:** Open `digest-skill/SKILL.md` in a split pane and walk the frontmatter top-down:
- `user-invocable: true` — appears in `/help` and the picker.
- `argument-hint: "<path> [focus] [length]"` — cosmetic; tells the user what to type.
- `arguments: { focus, length }` — named params accessible as `$focus` / `$length`.
- `allowed-tools: [Read, Bash]` — blast radius locked. Can't fetch URLs or write files.
- Body: `$1` (positional path), `$focus`, `$length` substituted at load time — before the model reads it.
- Summary: "Packaged instructions. Zero tokens until invoked. Progressive disclosure. The baseline."

**Subagent:** "Same SKILL.md. `context: fork` added. Isolated context. Only the result returns."
- Open `digest-subagent/SKILL.md` — point out it has the *same body*, just two new frontmatter lines.
- The `agent:` field is the isolated executor's system prompt — tight persona, no noise.

**Agent definition:** Open `.claude/agents/digester.md`:
- `model: claude-haiku-4-5-20251001` — the model is set in the definition, not at call time.
- `tools: [Read, Bash]` — syntax differs from `allowed-tools` in skills, same purpose.
- Always runs isolated — no `context: fork` needed; delegation implies isolation.
- "It's a thing, not a relationship. Any orchestrator can delegate to it by name."

**Agent loop:** "The orchestrator. Headless. Repeats. Its job is to decide and delegate."
- Open `digest-all.sh` — point at what's *not* there: no business logic, no digesting, just iteration.

### Part 3 — The live demos (15 min)

Run in order. Each one builds on the previous.

**Demo 1 — Skill (in-context, all characteristics on display)**

Before running: open `digest-skill/SKILL.md` in a split pane so the audience can
see the frontmatter live.

```
/digest-skill sample-doc.md "key risks" short
```

While it runs, narrate what's happening from the SKILL.md:
- `$1 = sample-doc.md` (positional param, path)
- `$focus = "key risks"` (named param from `arguments:` block)
- `$length = short` (named param — 3–5 bullets)
- The word count was injected by `` !`wc -w "$1"` `` *before* the model read the file.
  The model arrived knowing the doc was ~3,400 words — no tool call spent.
- `allowed-tools: [Read, Bash]` — the only tools available inside this skill.

After: **"Notice your context just grew. The word count injection, the full document
content, the digest, all of it is now in your session history. That's the in-context
cost. That's what we're about to isolate."**

**Demo 2 — Subagent + the diff (the talk's key moment)**

```
/digest-subagent sample-doc.md "key risks" short
```

After: "Same task. Same params. Same output format. Your context barely moved."

Now open both files side-by-side and run the diff:
```bash
git diff --no-index \
  .claude/skills/digest-skill/SKILL.md \
  .claude/skills/digest-subagent/SKILL.md
```

Point at the diff output and read it aloud: **"`context: fork` and `agent:`. That's it.
Two lines in the frontmatter. Same body. Completely different execution model. The full
document lived and died in a separate context. Only the digest came back."**

Pause. Let it land. This is the core lesson.

**Demo 3 — Agent definition (a named, constrained executor)**

Open `.claude/agents/digester.md` in a split pane. Walk the frontmatter before running:
- `model: claude-haiku-4-5-20251001` — haiku, not the session model. Set here, in the
  definition, for every caller that ever delegates to this agent.
- `tools: [Read, Bash]` — not `allowed-tools` (that's the skill syntax); this is the agent
  definition syntax. Same purpose: lock the blast radius at definition time, not call time.
- No `context: fork` needed — delegation always implies isolation.

Then say to Claude:
> "Use the digester agent to summarize sample-doc.md — focus on open questions, short."

Watch Claude delegate via the Agent tool. Point out: "Notice the model. Notice the tools.
Those aren't things the caller chose — they're properties of the agent. The caller just
said 'use digester.' The definition did the rest."

**Demo 4 — Agent loop (the orchestrator with no business logic)**

```bash
bash digest-all.sh --dry-run   # show the plan
bash digest-all.sh             # run it
cat digests/agentic-patterns-digest.md
```

Open `digest-all.sh` side-by-side. Read the content aloud — point at what's *not* there:
no digesting logic, no summarization, no format decisions. Just: loop over files, call
`claude --print "/digest-subagent"`, write the result. That's the entire script.

**"The loop decides what to run and repeats. The skill decides how. They don't know
about each other. Either one can be replaced without touching the other."**

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

Challenge: "Add a `format` param (`bullets` / `prose` / `table`) to `digest-skill`.
Then propagate it to `digest-subagent`. Edit the two files, count the lines changed,
and notice that the isolation logic doesn't need to change — only the body contract."

Files to edit:
- `.claude/skills/digest-skill/SKILL.md` — add `format` to `arguments:`, add handling in body
- `.claude/skills/digest-subagent/SKILL.md` — copy the same `arguments:` addition and body line

The agent loop (`digest-all.sh`) and the agent definition (`digester.md`) don't need
any changes. That's the composition payoff.

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
