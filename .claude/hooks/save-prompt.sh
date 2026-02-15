#!/bin/bash
set -euo pipefail

# UserPromptSubmit hook
# Appends every user prompt to prompts/ with a clean timestamp prefix.
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

# Extract prompt text and session_id via Python.
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

prompt = data.get("prompt", "").strip()
if not prompt:
    sys.exit(0)

session_id = data.get("session_id", "unknown")

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

# One file per session, append each prompt with a timestamp header.
session_file = os.path.join(prompts_dir, f"{session_id}.md")

with open(session_file, "a") as f:
    f.write(f"## {timestamp}\n\n{prompt}\n\n---\n\n")
PYEOF
