# Session Synthesis System

## Problem

Raw session logs (`sessions/*.md`) capture prompts, responses, and stats, but
synthesize nothing. The Claude Code transcript JSONL files
(`~/.claude/projects/<project>/<session-id>.jsonl`) contain even richer data —
token usage, compact summaries, causal graphs, model info — but are opaque
binary logs. Neither format answers the questions that matter:

- What did we accomplish? What's left?
- What patterns work? What wastes time?
- What does the next session need to know?

## Data sources

### 1. Session logs (`sessions/*.md`) — our hooks

Turn-by-turn markdown with stats tables. Human-readable, per-turn granularity.

| Field | Source hook | Example |
|-------|-----------|---------|
| User prompt | `save-prompt.sh` | Full prompt text |
| Assistant response | `save-response.sh` | Response text (truncated) |
| Tool breakdown | `save-response.sh` | `Bash(6), Read(3), Edit(2)` |
| Duration | `save-response.sh` | `2m 14s` |
| Files read/written | `save-response.sh` | Counts |
| Subagent table | `save-response.sh` | Type, model, tokens, duration |
| Git delta | `save-response.sh` | Commits, uncommitted changes |

### 2. Transcript JSONL (`~/.claude/projects/`) — Claude Code native

The authoritative record. Every entry has `sessionId`, `slug`, `timestamp`,
`cwd`, `gitBranch`. Key entry types:

| Entry type | Subtype | What it gives us |
|------------|---------|------------------|
| `assistant` | — | Full response + `message.usage` (input/output/cache tokens) |
| `user` | — | Prompts, tool results, `toolUseResult` with error flags |
| `user` | `isCompactSummary` | **Claude's own session narrative** — free retrospective |
| `system` | `compact_boundary` | `compactMetadata.preTokens` — context window pressure |
| `system` | `stop_hook_summary` | Hook execution, version, `preventedContinuation` |
| `progress` | — | Hook progress, status messages |
| `queue-operation` | — | Session resume/continuation events |

The `isCompactSummary` entries are especially valuable — Claude already wrote
a structured narrative of what happened before context was compacted. This is
*free synthesis input* that doesn't require another LLM call to generate.

### 3. Subagent JSONL (`~/.claude/projects/<session>/subagents/`)

Per-subagent transcripts with full tool call history. Useful for understanding
what background agents accomplished.

## Design principles

1. **Claude is the synthesizer.** This is an LLM generation task. No keyword
   index or embedding model can produce a retrospective.
2. **Use both data sources.** Session logs for human-readable stats. Transcript
   JSONL for token usage, compact summaries, and the causal graph.
3. **Synthesis runs between sessions, not during.** Don't burn tokens on
   meta-work while doing real work.
4. **Output feeds back in.** Synthesis artifacts must land somewhere that future
   sessions actually read (CLAUDE.md, agent_docs/).
5. **Incremental, not batch.** Process new sessions only. Append to rolling
   digest.

## Architecture

```
sessions/                     Raw turn-by-turn logs (hook-generated)
  └── <session-id>.md

~/.claude/projects/<project>/ Transcript JSONL (Claude Code native)
  ├── <session-id>.jsonl
  └── <session-id>/subagents/

syntheses/                    Generated synthesis artifacts
  ├── recaps/                 Per-session retrospectives
  │   └── YYYYMMDD_<slug>_<session-id-short>.md
  ├── digest.md               Rolling cross-session learning digest
  └── .synthesized            Tracks which sessions have been processed
```

File naming uses the `slug` from transcript metadata (e.g.,
`20260215_curious-dreaming-wand_4e36a3d0.md`) for human-scannable filenames.

## Artifact types

### 1. Session Recap (`syntheses/recaps/`)

One per session. ~50-100 lines. Generated after the session ends.

```markdown
# Session Recap — 2026-02-15 (curious-dreaming-wand)

Session: 4e36a3d0-6e8a-4695-9f46-9ccae94af71e
Duration: ~2h (3 context compactions)
Models: claude-opus-4-6, claude-haiku-4-5
Token spend: ~350K input, ~45K output

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

## Stats
- Turns: 12
- Tool calls: 87 (Bash: 34, Read: 22, Edit: 15, ...)
- Subagents: 3 (Explore: 2, Bash: 1)
- Errors: 2
- Context compactions: 3 (at 184K, 172K, ... tokens)
```

**Data flow for recap generation:**

1. Read `sessions/<id>.md` for the human-readable turn log
2. Read `<id>.jsonl` for:
   - `slug` → filename and title
   - `isCompactSummary` entries → pre-made narrative chunks
   - `message.usage` on assistant entries → aggregate token spend
   - `compact_boundary` entries → compaction count and pressure
   - First/last `timestamp` → session duration
3. Feed both into `claude --print` with the recap prompt
4. The compact summaries mean the LLM doesn't need to read thousands of raw
   lines — it reads the pre-digested narrative + stats

### 2. Learning Digest (`syntheses/digest.md`)

Rolling document. Not per-session — it's the accumulated wisdom. This is what
CLAUDE.md references so future sessions benefit.

```markdown
# Learning Digest

Last updated: 2026-02-15
Sessions synthesized: 4

## Project patterns
- [Effective patterns discovered for this specific codebase]

## Tool usage patterns
- [Which tool combinations work best for which tasks]

## Anti-patterns
- [Things that consistently waste time or cause errors]

## Codebase knowledge
- [Non-obvious things about the codebase learned through sessions]

## Session lineage
| Date | Slug | Turns | Tokens | Key outcome |
|------|------|-------|--------|-------------|
| 2026-02-15 | curious-dreaming-wand | 12 | 395K | Initial project seed |
```

**Why rolling:** A new session shouldn't have to read 20 recap files. The digest
is compressed, deduplicated knowledge. Old entries get refined or removed as
understanding evolves. The session lineage table provides a lightweight index.

## Trigger mechanism

### Option A: Manual script (start here)

```bash
scripts/synthesize.sh           # process all pending sessions
scripts/synthesize.sh <id>      # process a specific session
```

**Pros:** Zero overhead on session start. User controls when synthesis happens.
Good for iterating on the synthesis prompt.

### Option B: SessionStart hook (graduate to this)

A new hook checks for un-synthesized sessions at the start of each session.
Runs `claude --print` with session data and the synthesis prompt.

```
SessionStart
  → session-init.sh  (existing: env setup)
  → synthesize.sh    (new: process pending sessions)
```

**Pros:** Automatic. Synthesis of the *previous* session happens at the start
of the *next* one.

**Cons:** Adds ~15-30s to session startup. Requires `claude` CLI access.

### Option C: Stop hook — not viable

The Stop hook fires on every turn, not just session end. No "session end" event
exists in Claude Code hooks. Skip this.

**Recommendation:** Start with **Option A**. Graduate to **Option B** once the
synthesis prompt is stable.

## Synthesis engine (`scripts/synthesize.sh`)

Python script that:

1. Scans `sessions/*.md` for session IDs
2. Reads `.synthesized` to skip already-processed sessions
3. For each un-processed session:
   a. Extracts stats from `sessions/<id>.md`
   b. Extracts compact summaries + token usage from transcript JSONL
   c. Builds a condensed synthesis input (~2-5K tokens instead of full log)
   d. Calls `claude --print -p "<recap prompt>"` with the condensed input
   e. Writes recap to `syntheses/recaps/`
   f. Records session ID in `.synthesized`
4. If new recaps were generated, calls `claude --print` again with:
   - Current `digest.md`
   - New recap(s)
   - Digest update prompt
5. Writes updated `digest.md`

### Why compact summaries are the key insight

Without compact summaries, synthesizing a 1000-line JSONL transcript requires
sending ~100K+ tokens to the LLM. With compact summaries, we send:

- 1-3 compact summary texts (~2K tokens total)
- Aggregated stats table (~200 tokens)
- The session markdown turn log headings (~500 tokens)

Total: ~3-5K tokens per recap. Cheap enough to run on haiku.

### Why `claude --print` over raw API?

- Already installed in the environment
- Handles auth, model selection, context window
- `--print` mode is non-interactive, returns text to stdout
- No API key management needed
- Can use `--model haiku` for cost-efficient synthesis

## Feedback loop

### CLAUDE.md reference
```markdown
## Session learnings
See `syntheses/digest.md` for accumulated patterns and anti-patterns
from previous sessions.
```

### SessionStart context injection (future)
The SessionStart hook could inject the latest "open threads" from the most
recent recap into the session preamble, so Claude immediately knows what was
left unfinished.

## File tracking

`syntheses/.synthesized` — newline-delimited list of processed session IDs:

```
fad48f79-cb75-4306-929d-86168a4de6e6
8969f180-de06-4783-99d5-2048308b49b7
```

Intentionally simple — no database, no JSON, just append a line.

## What this is NOT

- **Not a search engine.** Keyword/semantic retrieval is complementary but
  separate. Synthesis is generation.
- **Not a dashboard.** Stats tables in session logs capture metrics. Synthesis
  is qualitative.
- **Not automatic documentation.** It doesn't update READMEs or architecture
  docs. It produces *retrospective* artifacts for human review and agent context.

## Implementation order

1. `scripts/synthesize.sh` — manual trigger, recap generation only
2. `syntheses/` directory structure with `.synthesized` tracking
3. Digest generation (depends on having 2-3 recaps first)
4. CLAUDE.md reference to digest
5. (Later) SessionStart hook for automatic synthesis
