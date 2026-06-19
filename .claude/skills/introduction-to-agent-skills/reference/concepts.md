# Concepts: Skills, Sub-agents, Agents, MCP Tools

*Deep reference for `introduction-to-agent-skills`. Not loaded until you open this file.*

---

## The core trade-off: reasoning vs determinism

Every choice in agentic system design comes down to one question:
**does this step need LLM reasoning, or can it be deterministic?**

Reasoning is expensive (tokens, latency, non-determinism). Determinism is cheap, fast,
and reproducible. The primitives exist to let you push as much as possible into the
deterministic bucket.

```
deterministic ◄────────────────────────────────► reasoning
   Tools/MCP        Skills       Sub-agents        Agent loop
   (pure I/O)   (packaged      (isolated LLM    (full autonomy,
                instructions)   reasoning)        orchestration)
```

---

## 1. Tools / MCP

**What:** Functions the model can call. Bash, Read, Write, WebFetch, WebSearch are built
in. MCP servers add domain-specific tools: Slack `chat.postMessage`, GitHub `create_pr`,
a custom DB query, etc.

**Cost:** Negligible. No LLM reasoning happens inside a tool call — it's just I/O.

**When to use:**
- Any action with a clear input → output contract (fetch a URL, write a file, post a message).
- Replace any natural-language instruction that is really just "run this command."

**Anti-pattern:** Wrapping a tool call in an agent when you don't need to. If `bash
slack-post.sh` gets the job done, don't build an agent around it.

---

## 2. Skill

**What:** A SKILL.md file that packages instructions, constraints, and a workflow. Only
`name` + `description` sit in the caller's context until the skill is invoked — the body
loads on demand (progressive disclosure). Runs **in the caller's context window**.

**Cost:** Zero until invoked. After invocation, the body adds to your context window.
If the body is 200 lines and triggers tool calls, those accumulate in your session.

**When to use:**
- Reusable, deterministic workflows you want to invoke by name.
- Anything that would otherwise require repeating a long system-prompt section.
- Multi-step processes that always follow the same structure.

**Progressive disclosure in practice:**
You can have 20 skills in `.claude/skills/` and they cost 0 tokens. Each one's
`description` is a ~2-sentence snippet in the picker. The full body only loads when
you type `/skill-name`. This is how large skill libraries stay manageable.

**Anti-pattern:** Putting everything in one giant skill body. Use `reference/` sub-files
and link to them — they won't load unless explicitly opened.

---

## 3. Sub-agent (`context: fork`)

**What:** The same SKILL.md with `context: fork` in the frontmatter. The runtime forks
a new, empty context window for this invocation. The sub-agent does its work (possibly
running many tool calls and accumulating thousands of tokens of history). When it
finishes, **only a summary** returns to the caller. The forked context is discarded.

**Cost:** The sub-agent pays for its own context. Your context stays clean — it only
grows by the size of the summary returned.

**When to use:**
- Large tasks that would bloat the caller's context (reading 20 web pages, summarizing
  a long doc, running a suite of checks).
- Independent tasks where you don't need the intermediate steps — just the result.
- Parallel workloads (multiple sub-agents running concurrently, each isolated).

**The one-line difference:**
```yaml
# skill (in-context)
name: my-skill

# sub-agent (isolated)
name: my-skill
context: fork
agent: You are a focused assistant for this isolated task.
```
That's it. Same SKILL.md structure, completely different execution model.

**Anti-pattern:** Forking when you need the result inline cheaply. If the task is small
(a quick grep, a 3-step flow), the forking overhead isn't worth it.

---

## 4. Agent Loop

**What:** An LLM running in a control loop, typically headless (`claude --print`), on a
schedule (cron / launchd / GitHub Actions). It reads instructions (a skill or system prompt),
decides which skills and tools to call, executes them, observes results, and continues
until the goal is met.

**Cost:** This is your most expensive primitive. Every iteration of the loop burns tokens.
Design the loop to be the *orchestrator*, not the *worker* — the worker logic lives in
skills and tools.

**When to use:**
- Fully autonomous workflows that run unattended (daily digest, CI-triggered analysis).
- Tasks that require multi-step reasoning: "read sources, decide what's interesting,
  summarize, post" — the agent decides; the skill executes.

**Headless invocation:**
```bash
claude --print \
  --allowedTools "WebFetch,WebSearch,Write,Read,Bash" \
  "/daily-curated-research"
```
`--print` means no interactive UI; the output goes to stdout. Wrap this in a shell script
and call it from cron. The skill provides the deterministic logic; the agent provides the
judgment.

**Control-plane decoupling:** The cron job doesn't know about skills or tools — it just
calls the script. The script doesn't hard-code the task — it loads the skill. The skill
doesn't know about the schedule — it just does its job. Each layer is replaceable.

---

## Composition pattern: the daily-research-skill

```
cron (every 24h)
  └─► run-daily.sh (the control plane)
        └─► claude --print "/daily-curated-research" (the agent loop)
              └─► reads sources.yaml (Read tool)
              └─► fetches sources (WebFetch / WebSearch tools)
              └─► summarizes findings (LLM reasoning, in-context)
              └─► writes /tmp/digest.txt (Write tool)
              └─► bash slack-post.sh < /tmp/digest.txt (Bash → curl → Slack API)
```

Each primitive in its right place:
- **cron + shell script** = control plane (no LLM)
- **`claude --print` + skill** = the agent loop + deterministic workflow
- **WebFetch, WebSearch, Bash** = the tools (hands)
- **slack-post.sh** = deterministic delivery (no LLM, just curl)

---

## Anti-patterns quick reference

| Anti-pattern | Better approach |
|---|---|
| Agent loop doing what a bash script can do | Move to a tool or shell script |
| Giant monolithic skill body | Split into `reference/` sub-files (progressive disclosure) |
| Forking for a 3-step task | Keep it in-context; forking has overhead |
| LLM reasoning inside a tool | Tools are deterministic I/O; push reasoning up |
| Hardcoding secrets in skill/script | `.env` only; gitignored; document in `.env.example` |
| One skill that does everything | Compose: one skill per responsibility |
