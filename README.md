# introduction-to-agent-skills

Teaching repo for the talk **"Introduction to Agent Skills"** — a hands-on tour of the
Claude Code agentic taxonomy using a **single example** (document digester) expressed
at each level.

**One task. Four expressions. Only the level changes.**

---

## The taxonomy

| Primitive | What it is | How you get it | Cost to caller |
|---|---|---|---|
| **Skill** | Reusable instructions. Runs in the **caller's context**. Zero tokens until invoked. | `SKILL.md` | Body + tool calls |
| **Subagent** | Isolated context. Only the result returns. Caller stays clean. | `SKILL.md` + `context: fork` | Summary only |
| **Agent** | Named, isolated executor. Fixed tools + model. Any orchestrator can delegate to it. | `.claude/agents/NAME.md` | Summary only |
| **Agent loop** | The orchestrator. Headless. Decides what to invoke and repeats. | `claude --print` in a shell | Full LLM per iter. |

The two "aha"s:
1. **Skill → Subagent = one line.** Add `context: fork` to any SKILL.md. Same body, isolated execution.
2. **The agent loop has no business logic.** Its job is to decide and repeat. All the "how" lives in skills.

---

## Quick start

```bash
git clone https://github.com/dacostagarcia/introduction-to-agent-skills
cd introduction-to-agent-skills
claude   # open Claude Code here
```

In Claude Code:

```
/introduction-to-agent-skills          # guided tour — start here
/digest-skill sample-doc.md            # expression 1: skill (in-context)
/digest-subagent sample-doc.md         # expression 2: subagent (isolated)
```

Then run the diff — this is the talk's key moment:

```bash
git diff --no-index \
  .claude/skills/digest-skill/SKILL.md \
  .claude/skills/digest-subagent/SKILL.md
```

Then, in Claude Code, ask:
> "Use the digester agent to summarize sample-doc.md, focusing on open questions, short."

That's expression 3 — the agent definition.

Finally, the agent loop:
```bash
bash digest-all.sh --dry-run   # see the plan
bash digest-all.sh             # run it
```

---

## Repo layout

```
introduction-to-agent-skills/
  sample-doc.md                          ★ the document the digester reads (long RFC)
  digest-all.sh                          ★ the agent loop (expression 4)
  docs/                                  corpus for the loop demo (2–3 .md files)
  digests/                               loop output written here
  TALK.md                                speaker guide: narrative, demo order, Q&A hooks
  .claude/
    agents/
      digester.md                        ★ expression 3: agent definition (haiku, Read+Bash only)
    skills/
      introduction-to-agent-skills/
        SKILL.md                         guided tour entry point
        reference/
          taxonomy.md                    deep breakdown: all four primitives with digest examples
          frontmatter.md                 every SKILL.md frontmatter field annotated
      digest-skill/SKILL.md              ★ expression 1: plain skill, fully parameterized
      digest-subagent/SKILL.md           ★ expression 2: identical body + context: fork
```

---

## The teaching diff

```bash
git diff --no-index \
  .claude/skills/digest-skill/SKILL.md \
  .claude/skills/digest-subagent/SKILL.md
```

Strip the name and description lines — what remains is:

```diff
+ context: fork
+ agent: You are a focused document digester running in an isolated context.
```

That's the entire lesson between a skill and a subagent.

---

## Params: everything the digest skill supports

```
/digest-skill <path> [focus] [length]
/digest-subagent <path> [focus] [length]
```

| Param | Type | Description |
|---|---|---|
| `$1` / `path` | positional | Path to the .md file to digest |
| `$focus` | named | Topic to emphasize (default: balanced overview) |
| `$length` | named | `short` (bullets) / `medium` (paragraph) / `long` (3 paragraphs) |

Dynamic injection: `` !`wc -w "$1"` `` pre-loads the word count before the model reads
the skill body. The model knows the doc size before it starts — no tool call needed.

---

## Installing globally

To use these skills in any project:

```bash
cp -r .claude/skills/* ~/.claude/skills/
cp -r .claude/agents/* ~/.claude/agents/
```

Skills in `~/.claude/skills/` and agents in `~/.claude/agents/` are available in every
Claude Code session.

---

## Production example

This repo teaches the primitives in isolation. To see all four working together in a
real nightly automation:

**[daily-research-skill](https://github.com/dacostagarcia/daily-research-skill)** —
reads AI news sources every 24h, summarizes, and posts to Slack. Uses:
- A skill (the digest workflow)
- Bash + curl as tools (Slack delivery)
- A headless agent loop (cron → `claude --print`)

---

## License

MIT. Clone it, fork it, use it in your talk.
