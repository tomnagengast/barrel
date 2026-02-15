#!/bin/bash
set -euo pipefail

# PostToolUse hook for ExitPlanMode
# Copies the plan file to plans/ with a clean timestamp prefix.
#
# Receives JSON on stdin:
#   { "tool_name", "tool_input", "tool_response", "session_id",
#     "transcript_path", "cwd" }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PLANS_DIR="$PROJECT_DIR/plans"
mkdir -p "$PLANS_DIR"

# Slurp stdin JSON into a temp file so Python can read it.
HOOK_JSON="$(mktemp)"
trap 'rm -f "$HOOK_JSON"' EXIT
cat > "$HOOK_JSON"

# Use Python to:
#   1. Extract transcript_path from the hook input
#   2. Scan the JSONL transcript for the last Write to an .md file
#   3. Print that file path (or empty string)
PLAN_FILE="$(python3 - "$HOOK_JSON" <<'PYEOF'
import json, sys, os

hook_json_path = sys.argv[1]

try:
    with open(hook_json_path) as f:
        hook_input = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    sys.exit(0)

transcript = hook_input.get("transcript_path", "")

if not transcript or not os.path.isfile(transcript):
    sys.exit(0)

last_md = None

with open(transcript) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        def check_block(block):
            """Return file_path if block is a Write to .md, else None."""
            if not isinstance(block, dict):
                return None
            name = block.get("name") or block.get("tool_name") or ""
            if name != "Write":
                return None
            inp = block.get("input") or block.get("tool_input") or {}
            fp = inp.get("file_path", "")
            if fp.endswith(".md"):
                return fp
            return None

        # Shape A: entry itself is a tool_use-like dict
        hit = check_block(entry)
        if hit:
            last_md = hit
            continue

        # Shape B: entry.content is a list of blocks
        content = entry.get("content")
        if isinstance(content, list):
            for block in content:
                hit = check_block(block)
                if hit:
                    last_md = hit

        # Shape C: entry.message.content is a list
        msg = entry.get("message")
        if isinstance(msg, dict):
            content = msg.get("content")
            if isinstance(content, list):
                for block in content:
                    hit = check_block(block)
                    if hit:
                        last_md = hit

print(last_md or "")
PYEOF
)" 2>/dev/null || true

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
    exit 0
fi

# Timestamp prefix: YYYYMMDD_HHMMSS
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"

# Clean basename
BASENAME="$(basename "$PLAN_FILE")"

DEST="$PLANS_DIR/${TIMESTAMP}_${BASENAME}"
cp "$PLAN_FILE" "$DEST"

echo "[barrel] Plan saved → $DEST"
