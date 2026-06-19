---
name: digest-skill
description: >
  Reads a local markdown document and returns a short digest. Accepts a file path,
  an optional focus topic, and an optional length (short/medium/long). Runs in the
  caller's context window. Use when you want to summarize a document and keep the
  intermediate work visible in the current session.
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
---

# Digest Skill — in-context execution

**You are running as a plain skill.** This skill body loaded into the **caller's context
window** when it was invoked. Everything you do here — reading the document, your
reasoning, the digest you produce — will accumulate in this session's history.

That's intentional for now. It's the baseline. Compare with `/digest-subagent` to see
what changes when we add `context: fork`.

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
   and report: `Error: file not found at $1`.

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
   This digest ran IN YOUR CONTEXT WINDOW.
   The full content of $1 (~!`wc -w "$1" 2>/dev/null | awk '{print $1}' || echo "?"` words)
   is now part of this session's history.

   To see the difference, run: /digest-subagent $1 $focus $length
   ──────────────────────────────────────────────────────────
   ```

---

*This is Demo Expression 1 of 4 — the baseline skill.*
*Next: `/digest-subagent` (same task, isolated context).*
