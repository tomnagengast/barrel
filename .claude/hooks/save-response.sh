#!/bin/bash
set -euo pipefail

# Stop hook
# Appends the assistant's final response, turn statistics, and subagent
# summaries to the session prompts file.
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
import json, sys, os, re, time, subprocess
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
tool_calls = Counter()        # tool_name -> count
tool_errors = 0
files_read = set()
files_written = set()
last_user_ts = None
turn_entry_count = 0

# Subagent tracking
# pending_tasks: tool_use_id -> {description, subagent_type, model, background}
pending_tasks = {}
# completed_subagents: list of dicts with full info
completed_subagents = []

in_current_turn = False


def _parse_task_notifications(text, completed_subagents):
    """Extract <task-notification> blocks from text."""
    for match in re.finditer(r"<task-notification>(.*?)</task-notification>", text, re.DOTALL):
        notif = match.group(1)
        tid = re.search(r"<task-id>(.*?)</task-id>", notif)
        status = re.search(r"<status>(.*?)</status>", notif)
        summary = re.search(r"<summary>(.*?)</summary>", notif)
        m_tokens = re.search(r"total_tokens:\s*(\d+)", notif)
        m_tools = re.search(r"tool_uses:\s*(\d+)", notif)
        m_dur = re.search(r"duration_ms:\s*(\d+)", notif)

        info = {
            "description": summary.group(1) if summary else "background agent",
            "subagent_type": "background",
            "background": True,
            "agent_id": tid.group(1) if tid else "?",
        }
        if m_tokens:
            info["tokens"] = int(m_tokens.group(1))
        if m_tools:
            info["tool_uses"] = int(m_tools.group(1))
        if m_dur:
            dur_ms = int(m_dur.group(1))
            if dur_ms < 60000:
                info["duration"] = f"{dur_ms / 1000:.1f}s"
            else:
                info["duration"] = f"{dur_ms // 60000}m {(dur_ms % 60000) // 1000}s"

        existing_ids = {s.get("agent_id") for s in completed_subagents}
        if info.get("agent_id") not in existing_ids:
            completed_subagents.append(info)


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
            last_assistant_texts = []
            tool_calls = Counter()
            tool_errors = 0
            files_read = set()
            files_written = set()
            pending_tasks = {}
            completed_subagents = []
            last_user_ts = timestamp
            turn_entry_count = 0
            in_current_turn = True

            # Check for <task-notification> in user messages (bg agent completions)
            msg = entry.get("message", {})
            content = msg.get("content", "")
            text = content if isinstance(content, str) else ""
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "text":
                        text += b.get("text", "")

            if "<task-notification>" in text:
                _parse_task_notifications(text, completed_subagents)

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
                    elif name == "Task":
                        # Track subagent launch
                        tool_id = block.get("id", "")
                        pending_tasks[tool_id] = {
                            "description": inp.get("description", "?"),
                            "subagent_type": inp.get("subagent_type", "?"),
                            "model": inp.get("model", "default"),
                            "background": inp.get("run_in_background", False),
                        }

        # Tool results
        if entry_type == "user" and "toolUseResult" in entry:
            result = entry.get("toolUseResult", {})
            if isinstance(result, dict) and result.get("is_error"):
                tool_errors += 1

            # Check if this is a Task result with usage metadata
            msg = entry.get("message", {})
            content = msg.get("content", "")
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict) or block.get("type") != "tool_result":
                        continue
                    tool_use_id = block.get("tool_use_id", "")
                    if tool_use_id not in pending_tasks:
                        continue

                    # Parse result content blocks for usage metadata
                    rc = block.get("content", "")
                    result_texts = []
                    if isinstance(rc, str):
                        result_texts.append(rc)
                    elif isinstance(rc, list):
                        for rb in rc:
                            if isinstance(rb, dict) and rb.get("type") == "text":
                                result_texts.append(rb.get("text", ""))

                    agent_info = pending_tasks[tool_use_id].copy()

                    for rt in result_texts:
                        # Parse usage metadata: total_tokens, tool_uses, duration_ms
                        m_tokens = re.search(r"total_tokens:\s*(\d+)", rt)
                        m_tools = re.search(r"tool_uses:\s*(\d+)", rt)
                        m_dur = re.search(r"duration_ms:\s*(\d+)", rt)
                        m_agent = re.search(r"agentId:\s*(\S+)", rt)

                        if m_tokens:
                            agent_info["tokens"] = int(m_tokens.group(1))
                        if m_tools:
                            agent_info["tool_uses"] = int(m_tools.group(1))
                        if m_dur:
                            dur_ms = int(m_dur.group(1))
                            if dur_ms < 60000:
                                agent_info["duration"] = f"{dur_ms / 1000:.1f}s"
                            else:
                                agent_info["duration"] = f"{dur_ms // 60000}m {(dur_ms % 60000) // 1000}s"
                        if m_agent:
                            agent_info["agent_id"] = m_agent.group(1)

                    completed_subagents.append(agent_info)
                    del pending_tasks[tool_use_id]

            # Check for <task-notification> in tool result user messages
            text = ""
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text += block.get("text", "")

            if "<task-notification>" in text:
                _parse_task_notifications(text, completed_subagents)


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

# ── Git delta ───────────────────────────────────────────────────────

git_stats = ""
try:
    result = subprocess.run(
        ["git", "log", "--oneline", "--since=30 minutes ago", "--format=%s"],
        capture_output=True, text=True, cwd=project_dir, timeout=5
    )
    commits = [l for l in result.stdout.strip().split("\n") if l]
    if commits:
        git_stats = f"{len(commits)} commit(s)"

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
    f"| Subagents | {len(completed_subagents)} |",
    f"| Stop reason | {stop_reason} |",
]
if git_stats:
    stats_lines.append(f"| Git | {git_stats} |")

stats_block = "\n".join(stats_lines)

# Subagents detail table
subagent_block = ""
if completed_subagents:
    rows = ["| Agent | Type | Model | Duration | Tokens | Tool uses |",
            "|-------|------|-------|----------|--------|-----------|"]
    for sa in completed_subagents:
        desc = sa.get("description", "?")
        if len(desc) > 40:
            desc = desc[:37] + "..."
        tokens = sa.get("tokens", "?")
        tokens_str = f"{tokens:,}" if isinstance(tokens, int) else str(tokens)
        rows.append(
            f"| {desc} "
            f"| {sa.get('subagent_type', '?')} "
            f"| {sa.get('model', '?')} "
            f"| {sa.get('duration', '?')} "
            f"| {tokens_str} "
            f"| {sa.get('tool_uses', '?')} |"
        )
    subagent_block = "\n".join(rows)

response = "\n\n".join(last_assistant_texts) if last_assistant_texts else "(no text response)"

with open(session_file, "a") as f:
    f.write(f"### Response ({timestamp})\n\n{response}\n\n")
    f.write(f"### Stats\n\n{stats_block}\n\n")
    if subagent_block:
        f.write(f"### Subagents\n\n{subagent_block}\n\n")
    f.write("---\n\n")
PYEOF
