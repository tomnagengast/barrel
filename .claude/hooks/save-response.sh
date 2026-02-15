#!/bin/bash
set -euo pipefail

# Stop hook
# Appends the assistant's final text response to the session prompts file,
# closing out the turn started by save-prompt.sh.
#
# Receives JSON on stdin:
#   { "stop_reason", "session_id", "transcript_path", "cwd", ... }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROMPTS_DIR="$PROJECT_DIR/prompts"
mkdir -p "$PROMPTS_DIR"

# Slurp stdin into a temp file.
HOOK_JSON="$(mktemp)"
trap 'rm -f "$HOOK_JSON"' EXIT
cat > "$HOOK_JSON"

# Parse the transcript for the last assistant text, append as "### Response".
python3 - "$HOOK_JSON" "$PROMPTS_DIR" <<'PYEOF'
import json, sys, os
from datetime import datetime

hook_json_path = sys.argv[1]
prompts_dir = sys.argv[2]

try:
    with open(hook_json_path) as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    sys.exit(0)

session_id = data.get("session_id", "unknown")
transcript_path = data.get("transcript_path", "")

session_file = os.path.join(prompts_dir, f"{session_id}.md")

# Only append if the session file exists (i.e. save-prompt.sh already ran)
if not os.path.isfile(session_file):
    sys.exit(0)

if not transcript_path or not os.path.isfile(transcript_path):
    sys.exit(0)

# Walk the transcript to collect the last assistant text blocks.
# Assistant messages may span multiple entries (tool calls interleaved),
# so we gather all text from the final contiguous assistant run.
last_assistant_texts = []

with open(transcript_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        entry_type = entry.get("type", "")

        if entry_type == "user" and "toolUseResult" not in entry:
            # A real user message resets the assistant accumulator
            last_assistant_texts = []
            continue

        if entry_type == "assistant":
            msg = entry.get("message", {})
            content = msg.get("content", "")
            texts = []
            if isinstance(content, str) and content.strip():
                texts.append(content.strip())
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        t = block.get("text", "").strip()
                        if t:
                            texts.append(t)
            if texts:
                last_assistant_texts.extend(texts)

if not last_assistant_texts:
    sys.exit(0)

response = "\n\n".join(last_assistant_texts)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

with open(session_file, "a") as f:
    f.write(f"### Response ({timestamp})\n\n{response}\n\n---\n\n")
PYEOF
