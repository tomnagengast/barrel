#!/bin/bash
set -euo pipefail

# Stop hook
# Appends the assistant's final response and turn statistics.
#
# Receives JSON on stdin:
#   { "stop_reason", "session_id", "transcript_path", "cwd", ... }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROMPTS_DIR="$PROJECT_DIR/prompts"
mkdir -p "$PROMPTS_DIR"

HOOK_JSON="$(mktemp)"
trap 'rm -f "$HOOK_JSON"' EXIT
cat > "$HOOK_JSON"

python3 - "$HOOK_JSON" "$PROMPTS_DIR" "$PROJECT_DIR" <<'PYEOF'
import json, sys, os, time, subprocess
from datetime import datetime
from collections import Counter

hook_json_path = sys.argv[1]
prompts_dir = sys.argv[2]
project_dir = sys.argv[3]

try:
    with open(hook_json_path) as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    sys.exit(0)

session_id = data.get("session_id", "unknown")
stop_reason = data.get("stop_reason", "unknown")
transcript_path = data.get("transcript_path", "")

session_file = os.path.join(prompts_dir, f"{session_id}.md")
if not os.path.isfile(session_file):
    sys.exit(0)
if not transcript_path or not os.path.isfile(transcript_path):
    sys.exit(0)

# ── Parse the transcript for the LAST turn ──────────────────────────

last_assistant_texts = []
tool_calls = Counter()       # tool_name -> count
tool_errors = 0
files_read = set()
files_written = set()
last_user_ts = None          # ISO timestamp of last real user message
turn_entry_count = 0         # total entries in this turn

in_current_turn = False

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
        timestamp = entry.get("timestamp", "")

        # Real user message (not a tool result) marks turn boundary
        if entry_type == "user" and "toolUseResult" not in entry:
            # Reset everything for the new turn
            last_assistant_texts = []
            tool_calls = Counter()
            tool_errors = 0
            files_read = set()
            files_written = set()
            last_user_ts = timestamp
            turn_entry_count = 0
            in_current_turn = True
            continue

        if not in_current_turn:
            continue

        turn_entry_count += 1

        if entry_type == "assistant":
            msg = entry.get("message", {})
            content = msg.get("content", "")
            blocks = []
            if isinstance(content, str) and content.strip():
                blocks = [{"type": "text", "text": content}]
            elif isinstance(content, list):
                blocks = content

            for block in blocks:
                if not isinstance(block, dict):
                    continue

                # Collect text
                if block.get("type") == "text":
                    t = block.get("text", "").strip()
                    if t:
                        last_assistant_texts.append(t)

                # Collect tool_use
                if block.get("type") == "tool_use":
                    name = block.get("name", "unknown")
                    tool_calls[name] += 1
                    inp = block.get("input", {})

                    if name in ("Read", "Glob"):
                        fp = inp.get("file_path", "") or inp.get("pattern", "")
                        if fp:
                            files_read.add(fp)
                    elif name in ("Write", "Edit"):
                        fp = inp.get("file_path", "")
                        if fp:
                            files_written.add(fp)

        # Tool results (user entries with toolUseResult)
        if entry_type == "user" and "toolUseResult" in entry:
            result = entry.get("toolUseResult", {})
            if isinstance(result, dict) and result.get("is_error"):
                tool_errors += 1

# ── Duration ────────────────────────────────────────────────────────

duration_str = "unknown"
marker_path = os.path.join(prompts_dir, f".turn_start_{session_id}")
if os.path.isfile(marker_path):
    try:
        with open(marker_path) as f:
            start_epoch = float(f.read().strip())
        elapsed = time.time() - start_epoch
        if elapsed < 60:
            duration_str = f"{elapsed:.0f}s"
        else:
            mins = int(elapsed // 60)
            secs = int(elapsed % 60)
            duration_str = f"{mins}m {secs}s"
        os.remove(marker_path)
    except (ValueError, OSError):
        pass

# ── Git delta (commits + diffstat since turn start) ─────────────────

git_stats = ""
try:
    # Count commits made during this turn (last 30 min window is generous)
    result = subprocess.run(
        ["git", "log", "--oneline", "--since=30 minutes ago", "--format=%s"],
        capture_output=True, text=True, cwd=project_dir, timeout=5
    )
    commits = [l for l in result.stdout.strip().split("\n") if l]
    if commits:
        git_stats = f"{len(commits)} commit(s)"

    # Shortstat for uncommitted changes
    result2 = subprocess.run(
        ["git", "diff", "--shortstat"],
        capture_output=True, text=True, cwd=project_dir, timeout=5
    )
    diff_stat = result2.stdout.strip()
    if diff_stat:
        git_stats += f" | uncommitted: {diff_stat}" if git_stats else diff_stat
except (subprocess.TimeoutExpired, FileNotFoundError):
    pass

# ── Build output ────────────────────────────────────────────────────

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
total_tool_calls = sum(tool_calls.values())

# Tool breakdown: "Read(5), Write(3), Bash(2)"
tool_summary = ", ".join(f"{name}({count})" for name, count in tool_calls.most_common())

stats_lines = [
    f"| Metric | Value |",
    f"|--------|-------|",
    f"| Duration | {duration_str} |",
    f"| Tool calls | {total_tool_calls} |",
    f"| Tool breakdown | {tool_summary or 'none'} |",
    f"| Errors | {tool_errors} |",
    f"| Files read | {len(files_read)} |",
    f"| Files written | {len(files_written)} |",
    f"| Stop reason | {stop_reason} |",
]
if git_stats:
    stats_lines.append(f"| Git | {git_stats} |")

stats_block = "\n".join(stats_lines)

response = "\n\n".join(last_assistant_texts) if last_assistant_texts else "(no text response)"

with open(session_file, "a") as f:
    f.write(f"### Response ({timestamp})\n\n{response}\n\n")
    f.write(f"### Stats\n\n{stats_block}\n\n---\n\n")
PYEOF
