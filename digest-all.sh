#!/usr/bin/env bash
# digest-all.sh — the agent loop
#
# Demo Expression 4 of 4: the AGENT LOOP.
#
# This shell script is the control plane. It has no business logic — it is a
# thin orchestrator that decides *what* to run and *repeats* it across a corpus.
# The business logic (how to digest a document) lives in digest-subagent/SKILL.md.
#
# Usage:
#   bash digest-all.sh                  # digest all docs/ files, write to digests/
#   bash digest-all.sh --dry-run        # print what would run, don't execute
#   bash digest-all.sh --focus "risks"  # pass a focus topic to every digest
#   bash digest-all.sh --length long    # override length for every digest
#
# Teaching note:
#   The agent loop is the most expensive primitive — it invokes `claude --print`
#   once per document. Each invocation is a full LLM call. Design loops to be thin:
#   this script does nothing except decide the list and invoke the skill.
#   The "doing" is in digest-subagent, not here.

set -euo pipefail

DOCS_DIR="${DOCS_DIR:-./docs}"
OUTPUT_DIR="${OUTPUT_DIR:-./digests}"
FOCUS=""
LENGTH="short"
DRY_RUN=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true; shift ;;
    --focus)     FOCUS="$2"; shift 2 ;;
    --length)    LENGTH="$2"; shift 2 ;;
    *)           echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# Validate
if [[ ! -d "$DOCS_DIR" ]]; then
  echo "Error: docs directory not found at $DOCS_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== digest-all.sh — agent loop ==="
echo "Docs:   $DOCS_DIR"
echo "Output: $OUTPUT_DIR"
echo "Focus:  ${FOCUS:-"(none — balanced overview)"}"
echo "Length: $LENGTH"
echo ""

# Collect documents
DOCS=( "$DOCS_DIR"/*.md )
if [[ ${#DOCS[@]} -eq 0 ]]; then
  echo "No .md files found in $DOCS_DIR" >&2
  exit 1
fi

echo "Found ${#DOCS[@]} document(s) to digest:"
for doc in "${DOCS[@]}"; do
  echo "  - $doc"
done
echo ""

if $DRY_RUN; then
  echo "[dry-run] Would invoke for each document:"
  for doc in "${DOCS[@]}"; do
    out="$OUTPUT_DIR/$(basename "$doc" .md)-digest.md"
    echo "  claude --print --allowedTools 'Read,Bash' \"/digest-subagent $doc $FOCUS $LENGTH\""
    echo "  → $out"
  done
  echo ""
  echo "[dry-run] No documents were processed."
  exit 0
fi

# The loop — one claude --print invocation per document
SUCCESS=0
FAIL=0

for doc in "${DOCS[@]}"; do
  out="$OUTPUT_DIR/$(basename "$doc" .md)-digest.md"
  echo "Digesting: $doc → $out"

  if claude --print \
       --allowedTools "Read,Bash" \
       "/digest-subagent $doc $FOCUS $LENGTH" \
       > "$out" 2>&1; then
    echo "  ✓ done"
    ((SUCCESS++)) || true
  else
    echo "  ✗ failed (exit $?) — see $out for details"
    ((FAIL++)) || true
  fi
done

echo ""
echo "=== Done: $SUCCESS succeeded, $FAIL failed ==="

# Teaching note (printed to stderr so it doesn't go into any redirect)
>&2 echo ""
>&2 echo "Teaching note:"
>&2 echo "  This script is the AGENT LOOP — the orchestrator."
>&2 echo "  It ran claude --print ${#DOCS[@]} time(s) — one per document."
>&2 echo "  Each invocation is a fresh LLM call (expensive)."
>&2 echo "  The business logic lives in digest-subagent/SKILL.md, not here."
>&2 echo "  The loop's job: decide what to run and repeat. That's it."
