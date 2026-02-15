# Session Synthesis System

## Problem

Raw session logs (`sessions/*.md`) capture everything but synthesize nothing.
Reviewing 500-line session files to recall what happened, what worked, and what
to do differently is tedious. The logs are write-heavy, read-rarely in their
raw form.

We need a system that distills session logs into useful artifacts that improve
future sessions and support human retrospectives.

## Design principles

1. **Claude is the synthesizer.** This is an LLM generation task, not a search
   task. No keyword index or embedding model can produce a retrospective.
2. **Synthesis runs between sessions, not during.** Don't burn tokens on
   meta-work while doing real work. Synthesize after a session ends or before
   the next one starts.
3. **Output feeds back in.** Synthesis artifacts must land somewhere that future
   Claude Code sessions actually read (CLAUDE.md, agent_docs/, or session
   preamble via hooks).
4. **Incremental, not batch.** Synthesize the latest un-processed sessions,
   append to a rolling digest. Don't re-process everything each time.

## Architecture

```
sessions/              Raw turn-by-turn logs (existing)
  ├── <session-id>.md
  └── ...

syntheses/             Generated synthesis artifacts
  ├── recaps/          Per-session retrospectives
  │   └── YYYYMMDD_HHMMSS_<session-id-short>.md
  ├── digest.md        Rolling cross-session learning digest
  └── .synthesized     Tracks which sessions have been processed
```

## Artifact types

### 1. Session Recap (`syntheses/recaps/`)

One per session. Generated after the session ends. ~50-100 lines.

```markdown
# Session Recap — 2026-02-15

## What happened
- [1-3 sentence narrative of what was accomplished]

## Key decisions
- [Decisions made and their rationale]

## What worked
- [Effective patterns, tools, approaches]

## What didn't
- [Blockers, wrong turns, wasted effort]

## Artifacts produced
- [Files created/modified, commits, PRs]

## Open threads
- [Unfinished work, things to pick up next]
```

**Why this format:** Each section answers a specific retrospective question.
Human-scannable in 30 seconds. The "open threads" section is the most valuable —
it's the handoff to the next session.

### 2. Learning Digest (`syntheses/digest.md`)

Rolling document, appended to after each recap. Not per-session — it's the
accumulated wisdom across all sessions. This is what gets referenced in
CLAUDE.md for future sessions.

```markdown
# Learning Digest

Last updated: 2026-02-15

## Project patterns
- [Effective patterns discovered for this specific codebase]

## Tool usage patterns
- [Which tool combinations work best for which tasks]

## Anti-patterns
- [Things that consistently waste time or cause errors]

## Codebase knowledge
- [Non-obvious things about the codebase learned through sessions]
```

**Why rolling:** A new session shouldn't have to read 20 recap files. The digest
is the compressed, deduplicated knowledge. Old entries get refined or removed as
understanding evolves.

## Trigger mechanism

### Option A: SessionStart hook (recommended)

A new hook checks for un-synthesized sessions at the start of each session.
Runs `claude --print` (non-interactive) with the session log as context and a
synthesis prompt. Writes output to `syntheses/`.

```
SessionStart
  → session-init.sh (existing: env setup)
  → synthesize.sh   (new: process pending sessions)
```

**Pros:** Automatic, no manual step. Synthesis of the *previous* session happens
at the start of the *next* one, when the human is least likely to notice the
delay.

**Cons:** Adds ~10-20s to session startup. Requires `claude` CLI or API access.

### Option B: Manual script

```bash
scripts/synthesize.sh           # process all pending sessions
scripts/synthesize.sh <id>      # process a specific session
```

**Pros:** Zero overhead on session start. User controls when synthesis happens.

**Cons:** Easy to forget. Synthesis falls behind.

### Option C: Stop hook (end of session)

Run synthesis as the session ends. The session data is freshest.

**Cons:** User is leaving — they don't want to wait. Also, the Stop hook fires
on every turn, not just session end. Would need a separate "session end" signal
(doesn't currently exist in Claude Code hooks).

**Recommendation:** Start with **Option B** (manual script). Graduate to
**Option A** once the synthesis prompt is dialed in. Option C isn't viable
with current hook events.

## Synthesis engine

The synthesizer is a Python script that:

1. Reads `.synthesized` to find which sessions are already processed
2. For each un-processed session file:
   a. Reads the raw session markdown
   b. Calls `claude --print -p "synthesis prompt" < session.md`
      (or uses the Anthropic API directly with `python-sdk`)
   c. Parses the structured output
   d. Writes recap to `syntheses/recaps/`
   e. Appends/updates `syntheses/digest.md`
   f. Records session ID in `.synthesized`

### Why `claude --print` over raw API?

- Already installed in the environment
- Handles auth, model selection, context window
- `--print` mode is non-interactive, returns text to stdout
- No API key management needed

### Synthesis prompt (recap)

```
You are reviewing a Claude Code session log for a macOS markdown editor project.
Produce a structured retrospective with these sections:

## What happened
[1-3 sentence narrative]

## Key decisions
[Bulleted list of decisions and rationale]

## What worked
[Effective patterns]

## What didn't
[Blockers, wrong turns]

## Artifacts produced
[Files, commits]

## Open threads
[Unfinished work for next session]

Be concise. Each section should be 1-5 bullet points max.
Focus on what a future session needs to know, not a play-by-play.
```

### Synthesis prompt (digest update)

```
You are updating a rolling learning digest for a macOS markdown editor project.

Here is the current digest:
<current_digest>
{digest.md contents}
</current_digest>

Here is a new session recap:
<new_recap>
{recap contents}
</new_recap>

Update the digest by:
1. Adding new patterns/anti-patterns/knowledge from this recap
2. Reinforcing existing entries that were confirmed again
3. Removing or revising entries that were contradicted
4. Keeping the digest under 100 lines — compress, don't accumulate

Return the complete updated digest.
```

## Feedback loop

The digest needs to actually reach future sessions. Two mechanisms:

### CLAUDE.md reference
Add to CLAUDE.md:
```markdown
## Session learnings
See `syntheses/digest.md` for accumulated patterns and anti-patterns
from previous sessions.
```

Claude Code reads CLAUDE.md at session start, and the progressive disclosure
pattern means it will read the digest when relevant.

### SessionStart context injection (future)
Once synthesis is automated, the SessionStart hook could inject the latest
"open threads" into the session preamble so Claude immediately knows what
was left unfinished.

## File tracking

`syntheses/.synthesized` is a simple newline-delimited list of session IDs:

```
fad48f79-cb75-4306-929d-86168a4de6e6
8969f180-de06-4783-99d5-2048308b49b7
```

This is intentionally simple — no database, no JSON, just append a line.

## What this is NOT

- **Not a search engine.** QMD or similar can index sessions for keyword/semantic
  retrieval. That's complementary but separate. Synthesis is generation.
- **Not a dashboard.** The stats tables in session logs already capture metrics.
  Synthesis is qualitative, not quantitative.
- **Not automatic documentation.** It doesn't update READMEs or architecture
  docs. It produces *retrospective* artifacts for human review and agent context.

## Implementation order

1. `scripts/synthesize.sh` — manual trigger, recap generation only
2. `syntheses/` directory structure with `.synthesized` tracking
3. Digest generation (depends on having 2-3 recaps first)
4. CLAUDE.md reference to digest
5. (Later) SessionStart hook for automatic synthesis
