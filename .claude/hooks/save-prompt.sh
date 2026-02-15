#!/bin/bash
set -euo pipefail

# UserPromptSubmit hook
# Logs the user prompt as the start of a new turn.
# Also writes a marker file with the start timestamp for duration calc.
#
# Receives JSON on stdin:
#   { "prompt", "session_id", "transcript_path", "cwd", ... }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROMPTS_DIR="$PROJECT_DIR/prompts"
mkdir -p "$PROMPTS_DIR"

# Slurp stdin into a temp file.
HOOK_JSON="$(mktemp)"
trap 'rm -f "$HOOK_JSON"' EXIT
cat > "$HOOK_JSON"

python3 - "$HOOK_JSON" "$PROMPTS_DIR" <<'PYEOF'
import json, sys, os, time
from datetime import datetime

hook_json_path = sys.argv[1]
prompts_dir = sys.argv[2]

try:
    with open(hook_json_path) as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    sys.exit(0)

prompt = data.get("prompt", "").strip()
if not prompt:
    sys.exit(0)

session_id = data.get("session_id", "unknown")
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

session_file = os.path.join(prompts_dir, f"{session_id}.md")

with open(session_file, "a") as f:
    f.write(f"## {timestamp}\n\n### Prompt\n\n{prompt}\n\n")

# Write a marker with epoch time for duration calc by save-response.sh
marker = os.path.join(prompts_dir, f".turn_start_{session_id}")
with open(marker, "w") as f:
    f.write(str(time.time()))
PYEOF
