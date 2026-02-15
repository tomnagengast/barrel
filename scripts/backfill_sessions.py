#!/usr/bin/env python3
"""Backfill session logs from Claude Code transcript JSONL files.

Reads the authoritative transcript data from ~/.claude/projects/ and
regenerates sessions/*.md files with correct response text, tool call
counts, and subagent summaries.

Usage:
    python3 scripts/backfill_sessions.py              # backfill all sessions
    python3 scripts/backfill_sessions.py <session-id>  # backfill one session
"""

import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
SESSIONS_DIR = PROJECT_DIR / "sessions"
TRANSCRIPTS_DIR = Path.home() / ".claude" / "projects" / "-home-user-barrel"


def find_transcripts():
    """Find all transcript JSONL files and map session IDs to files."""
    session_to_file = {}
    if not TRANSCRIPTS_DIR.exists():
        return session_to_file

    for jsonl in sorted(TRANSCRIPTS_DIR.glob("*.jsonl")):
        # The JSONL filename IS the session ID
        sid = jsonl.stem
        # Check if this file has entries for this session
        try:
            with open(jsonl) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    entry_sid = entry.get("sessionId", "")
                    if entry_sid == sid:
                        session_to_file[sid] = jsonl
                        break
        except OSError:
            continue

    return session_to_file


def parse_task_notifications(text):
    """Extract <task-notification> blocks from text."""
    subagents = []
    for match in re.finditer(
        r"<task-notification>(.*?)</task-notification>", text, re.DOTALL
    ):
        notif = match.group(1)
        summary = re.search(r"<summary>(.*?)</summary>", notif)
        tid = re.search(r"<task-id>(.*?)</task-id>", notif)
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
                info["duration"] = (
                    f"{dur_ms // 60000}m {(dur_ms % 60000) // 1000}s"
                )
        subagents.append(info)
    return subagents


def extract_user_text(entry):
    """Get text content from a user entry."""
    msg = entry.get("message", {})
    content = msg.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text":
                parts.append(b.get("text", ""))
        return "".join(parts)
    return ""


def iso_to_local(iso_str):
    """Convert ISO timestamp to local datetime string YYYYMMDD_HHMMSS."""
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        # Convert to local time
        local_dt = dt.astimezone()
        return local_dt.strftime("%Y%m%d_%H%M%S")
    except (ValueError, AttributeError):
        return "unknown"


def format_duration(start_iso, end_iso):
    """Calculate duration between two ISO timestamps."""
    try:
        start = datetime.fromisoformat(start_iso.replace("Z", "+00:00"))
        end = datetime.fromisoformat(end_iso.replace("Z", "+00:00"))
        elapsed = (end - start).total_seconds()
        if elapsed < 60:
            return f"{elapsed:.0f}s"
        mins = int(elapsed // 60)
        secs = int(elapsed % 60)
        return f"{mins}m {secs}s"
    except (ValueError, AttributeError):
        return "unknown"


def process_session(session_id, transcript_path):
    """Parse a transcript JSONL and build the session log content."""
    turns = []  # List of (prompt_ts, prompt_text, responses)
    # Each response: (end_ts, texts, tool_calls, tool_errors, files_read, files_written, subagents)

    current_prompt_ts = None
    current_prompt_text = None

    # Accumulate response data for the current turn
    assistant_texts = []
    tool_calls = Counter()
    tool_errors = 0
    files_read = set()
    files_written = set()
    pending_tasks = {}
    completed_subagents = []
    last_assistant_ts = None
    in_turn = False

    # Track all stop points (system stop_hook_summary entries mark response boundaries)
    # But we don't have those reliably, so we'll detect turn boundaries from user entries

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
            entry_session = entry.get("sessionId", "")
            timestamp = entry.get("timestamp", "")

            # Only process entries from this session
            if entry_session and entry_session != session_id:
                continue

            # Skip non-message types
            if entry_type not in ("user", "assistant"):
                continue

            # User entry (not tool result) = new turn boundary
            if entry_type == "user" and "toolUseResult" not in entry:
                # Skip compact summaries and transcript-only entries
                if entry.get("isCompactSummary") or entry.get(
                    "isVisibleInTranscriptOnly"
                ):
                    continue

                # Save previous turn's data
                if in_turn and current_prompt_ts:
                    response_text = (
                        "\n\n".join(assistant_texts)
                        if assistant_texts
                        else "(no text response)"
                    )
                    turns.append(
                        {
                            "prompt_ts": current_prompt_ts,
                            "prompt_text": current_prompt_text,
                            "response_ts": last_assistant_ts or current_prompt_ts,
                            "response_text": response_text,
                            "tool_calls": dict(tool_calls.most_common()),
                            "tool_errors": tool_errors,
                            "files_read": len(files_read),
                            "files_written": len(files_written),
                            "subagents": list(completed_subagents),
                        }
                    )

                # Start new turn
                current_prompt_ts = timestamp
                current_prompt_text = extract_user_text(entry)
                assistant_texts = []
                tool_calls = Counter()
                tool_errors = 0
                files_read = set()
                files_written = set()
                pending_tasks = {}
                completed_subagents = []
                last_assistant_ts = None
                in_turn = True

                # Check for task notifications in user message
                if "<task-notification>" in current_prompt_text:
                    completed_subagents.extend(
                        parse_task_notifications(current_prompt_text)
                    )
                continue

            if not in_turn:
                continue

            # Assistant entry
            if entry_type == "assistant":
                last_assistant_ts = timestamp
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
                    if block.get("type") == "text":
                        t = block.get("text", "").strip()
                        if t:
                            assistant_texts.append(t)
                    if block.get("type") == "tool_use":
                        name = block.get("name", "unknown")
                        tool_calls[name] += 1
                        inp = block.get("input", {})
                        if name in ("Read", "Glob"):
                            fp = inp.get("file_path", "") or inp.get(
                                "pattern", ""
                            )
                            if fp:
                                files_read.add(fp)
                        elif name in ("Write", "Edit"):
                            fp = inp.get("file_path", "")
                            if fp:
                                files_written.add(fp)
                        elif name == "Task":
                            tool_id = block.get("id", "")
                            pending_tasks[tool_id] = {
                                "description": inp.get("description", "?"),
                                "subagent_type": inp.get("subagent_type", "?"),
                                "model": inp.get("model", "default"),
                                "background": inp.get(
                                    "run_in_background", False
                                ),
                            }

            # Tool result
            if entry_type == "user" and "toolUseResult" in entry:
                result = entry.get("toolUseResult", {})
                if isinstance(result, dict) and result.get("is_error"):
                    tool_errors += 1

                msg = entry.get("message", {})
                content = msg.get("content", "")
                if isinstance(content, list):
                    for block in content:
                        if (
                            not isinstance(block, dict)
                            or block.get("type") != "tool_result"
                        ):
                            continue
                        tool_use_id = block.get("tool_use_id", "")
                        if tool_use_id not in pending_tasks:
                            continue

                        rc = block.get("content", "")
                        result_texts = []
                        if isinstance(rc, str):
                            result_texts.append(rc)
                        elif isinstance(rc, list):
                            for rb in rc:
                                if (
                                    isinstance(rb, dict)
                                    and rb.get("type") == "text"
                                ):
                                    result_texts.append(rb.get("text", ""))

                        agent_info = pending_tasks[tool_use_id].copy()
                        for rt in result_texts:
                            m_tokens = re.search(
                                r"total_tokens:\s*(\d+)", rt
                            )
                            m_tools = re.search(r"tool_uses:\s*(\d+)", rt)
                            m_dur = re.search(r"duration_ms:\s*(\d+)", rt)
                            m_agent = re.search(r"agentId:\s*(\S+)", rt)
                            if m_tokens:
                                agent_info["tokens"] = int(
                                    m_tokens.group(1)
                                )
                            if m_tools:
                                agent_info["tool_uses"] = int(
                                    m_tools.group(1)
                                )
                            if m_dur:
                                dur_ms = int(m_dur.group(1))
                                if dur_ms < 60000:
                                    agent_info["duration"] = (
                                        f"{dur_ms / 1000:.1f}s"
                                    )
                                else:
                                    agent_info["duration"] = f"{dur_ms // 60000}m {(dur_ms % 60000) // 1000}s"
                            if m_agent:
                                agent_info["agent_id"] = m_agent.group(1)

                        completed_subagents.append(agent_info)
                        del pending_tasks[tool_use_id]

                # Check for task notifications in tool results
                text = ""
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    for block in content:
                        if (
                            isinstance(block, dict)
                            and block.get("type") == "text"
                        ):
                            text += block.get("text", "")
                if "<task-notification>" in text:
                    completed_subagents.extend(
                        parse_task_notifications(text)
                    )

    # Save final turn
    if in_turn and current_prompt_ts:
        response_text = (
            "\n\n".join(assistant_texts)
            if assistant_texts
            else "(no text response)"
        )
        turns.append(
            {
                "prompt_ts": current_prompt_ts,
                "prompt_text": current_prompt_text,
                "response_ts": last_assistant_ts or current_prompt_ts,
                "response_text": response_text,
                "tool_calls": dict(tool_calls.most_common()),
                "tool_errors": tool_errors,
                "files_read": len(files_read),
                "files_written": len(files_written),
                "subagents": list(completed_subagents),
            }
        )

    return turns


def format_session_log(turns):
    """Format turns into session log markdown."""
    output = []
    for turn in turns:
        prompt_ts = iso_to_local(turn["prompt_ts"])
        response_ts = iso_to_local(turn["response_ts"])
        duration = format_duration(turn["prompt_ts"], turn["response_ts"])

        output.append(f"## {prompt_ts}\n")
        output.append(f"### Prompt\n")
        output.append(f"{turn['prompt_text']}\n")

        output.append(f"### Response ({response_ts})\n")
        output.append(f"{turn['response_text']}\n")

        # Stats table
        total_tools = sum(turn["tool_calls"].values())
        tool_summary = ", ".join(
            f"{name}({count})" for name, count in turn["tool_calls"].items()
        )

        output.append("### Stats\n")
        output.append("| Metric | Value |")
        output.append("|--------|-------|")
        output.append(f"| Duration | {duration} |")
        output.append(f"| Tool calls | {total_tools} |")
        output.append(f"| Tool breakdown | {tool_summary or 'none'} |")
        output.append(f"| Errors | {turn['tool_errors']} |")
        output.append(f"| Files read | {turn['files_read']} |")
        output.append(f"| Files written | {turn['files_written']} |")
        output.append(f"| Subagents | {len(turn['subagents'])} |")

        # Subagent table
        if turn["subagents"]:
            output.append("")
            output.append("### Subagents\n")
            output.append(
                "| Agent | Type | Model | Duration | Tokens | Tool uses |"
            )
            output.append(
                "|-------|------|-------|----------|--------|-----------|"
            )
            for sa in turn["subagents"]:
                desc = sa.get("description", "?")
                if len(desc) > 40:
                    desc = desc[:37] + "..."
                tokens = sa.get("tokens", "?")
                tokens_str = (
                    f"{tokens:,}" if isinstance(tokens, int) else str(tokens)
                )
                output.append(
                    f"| {desc} "
                    f"| {sa.get('subagent_type', '?')} "
                    f"| {sa.get('model', '?')} "
                    f"| {sa.get('duration', '?')} "
                    f"| {tokens_str} "
                    f"| {sa.get('tool_uses', '?')} |"
                )

        output.append("")
        output.append("---\n")

    return "\n".join(output)


def main():
    target_session = sys.argv[1] if len(sys.argv) > 1 else None
    session_map = find_transcripts()

    if not session_map:
        print("No transcripts found in", TRANSCRIPTS_DIR)
        sys.exit(1)

    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)

    if target_session:
        # Find matching session
        matches = [
            sid for sid in session_map if sid.startswith(target_session)
        ]
        if not matches:
            print(f"No session matching '{target_session}' found")
            print("Available:", ", ".join(s[:8] for s in session_map))
            sys.exit(1)
        sessions_to_process = {m: session_map[m] for m in matches}
    else:
        sessions_to_process = session_map

    for session_id, transcript_path in sorted(sessions_to_process.items()):
        print(f"\nProcessing {session_id[:8]}...")
        print(f"  Transcript: {transcript_path}")

        turns = process_session(session_id, transcript_path)
        print(f"  Turns found: {len(turns)}")

        if not turns:
            print("  Skipping — no turns found")
            continue

        # Show summary of each turn
        for i, turn in enumerate(turns):
            total_tools = sum(turn["tool_calls"].values())
            has_text = turn["response_text"] != "(no text response)"
            prompt_preview = turn["prompt_text"][:50].replace("\n", " ")
            print(
                f"  Turn {i}: {prompt_preview}... "
                f"[tools={total_tools} text={'yes' if has_text else 'NO'}]"
            )

        # Write session file
        session_file = SESSIONS_DIR / f"{session_id}.md"
        content = format_session_log(turns)
        session_file.write_text(content)
        print(f"  Wrote {session_file} ({len(content)} bytes)")


if __name__ == "__main__":
    main()
