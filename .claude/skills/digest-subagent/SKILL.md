---
name: digest-subagent
description: >
  Reads a local markdown document and returns a short digest — identical to digest-skill,
  but runs in an isolated subagent context. Only the final digest is returned to the
  caller; the full document and intermediate reasoning are discarded. Use when you want
  to protect the caller's context window from the cost of reading a large document.
user-invocable: true
argument-hint: "<path> [focus] [length: short|medium|long]"
arguments:
  focus:
    description: The topic or angle to emphasize in the digest. Defaults to a balanced overview.
    required: false
  length:
    description: "Digest length: short (3–5 bullets), medium (1 paragraph), long (3 paragraphs). Default: short."
    required: false
allowed-tools:
  - Read
  - Bash
context: fork
agent: >
  You are a focused document digester running in an isolated context. Your only job is
  to read the document at the specified path, produce the requested digest, and return
  it. Do not ask clarifying questions. Keep your output clean — it is the only thing
  that returns to the caller.
---

# Digest Subagent — isolated execution

**You are running as a subagent.** This context window is completely separate from the
caller's. Everything you do here — reading the document, your intermediate reasoning,
any tool calls — stays here. When you finish, **only your final digest** is returned.
This context is then discarded.

The caller's context window does not grow, regardless of how large this document is.

---

## Parameters received

- **Document path:** `$1`
- **Focus topic:** `$focus` *(default: balanced overview)*
- **Length:** `$length` *(default: short)*

## Document stats (injected before you read this)

Word count of `$1`: !`wc -w "$1" 2>/dev/null | awk '{print $1}' || echo "unknown"` words

---

## Instructions

1. **Read the document** at `$1` using the Read tool. If the file does not exist, stop
   and return: `Error: file not found at $1`.

2. **Produce the digest** with the following constraints:
   - Focus on: `$focus` (if empty, give a balanced overview of the main themes)
   - Length: `$length`
     - `short` → 3–5 bullet points, each one sentence
     - `medium` → one paragraph (~100 words)
     - `long` → three paragraphs: overview, key details, implications
   - Never invent content not present in the document.
   - Include the source path in the output header.

3. **Append a teaching note** (since this is a demo):

   ```
   ─── Teaching note ────────────────────────────────────────
   This digest ran in an ISOLATED SUBAGENT CONTEXT.
   The full content of $1 is gone — only this digest returned.
   The caller's context window did not grow.

   To see the one-line difference from digest-skill, run:
   git diff --no-index \
     .claude/skills/digest-skill/SKILL.md \
     .claude/skills/digest-subagent/SKILL.md
   ──────────────────────────────────────────────────────────
   ```

---

*This is Demo Expression 2 of 4 — skill + `context: fork` = subagent.*
*The diff between this file and `digest-skill/SKILL.md` is the entire lesson.*
