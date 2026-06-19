# Tool Design Principles

Guidelines for building effective tools in Claude Code agentic systems.

## What makes a good tool

A good tool is:

1. **Deterministic.** Same input, same output, every time. No LLM reasoning inside.
2. **Bounded.** Does one thing. Not a Swiss Army knife with branching paths.
3. **Explicit about failure.** Returns a clear error on failure. Exits non-zero. Never
   silently succeeds when it didn't do what was asked.
4. **Free of side effects on read.** Reading tools (file reads, API GETs) should not
   modify state. Writing tools should be clearly labeled as such.
5. **Small blast radius.** Accepts only the inputs it needs. Does not have access to
   tokens, credentials, or files it doesn't need for its specific function.

## The Bash vs MCP decision

Use **Bash (shell scripts)** when:
- The action is local and self-contained (read a file, write to disk, run a command).
- You control the environment and don't need a network protocol.
- You want minimal dependencies.

Use **MCP** when:
- The action requires a structured API (Slack, GitHub, Jira, a custom service).
- You need proper authentication and request signing.
- Multiple agents across different projects need the same tool — MCP servers can be
  shared; shell scripts need to be copied.

Both are valid. The choice is about scope, not quality.

## Secret handling in tools

Tools frequently need credentials. The correct pattern:

```bash
# In the calling shell script, BEFORE invoking claude:
source .env  # sets SLACK_BOT_TOKEN, API_KEY, etc.

# In the tool (bash script):
TOKEN="${SLACK_BOT_TOKEN:?SLACK_BOT_TOKEN must be set}"
```

The `${VAR:?message}` pattern causes the script to exit with an error if the variable
is unset, rather than silently using an empty string. This is the correct failure mode.

**Never:**
- Hardcode credentials in a script that is committed to git.
- Pass credentials as command-line arguments (they appear in `ps` output).
- Log credentials (even partially) — log the action, not the credential.

## Output format conventions

Tools that return data for a calling agent to parse should:
- Return JSON for structured data (easier for the model to parse reliably).
- Return plain text for human-readable output (log lines, success messages).
- Return exit code 0 on success, non-zero on failure, always.
- Write errors to stderr, data to stdout.

If your tool outputs JSON on success and a plain-text error on failure, the caller
cannot reliably determine whether to parse the output as JSON. Pick one format for
the success case; write all errors to stderr.
