# Barrel — macOS Markdown Editor

A native macOS AppKit Markdown editor with incremental live preview.

## Quick start

```bash
scripts/check.sh    # format + lint + build + test
scripts/test.sh     # unit tests only
scripts/perf_smoke.sh  # performance smoke tests against fixtures
```

## Repo map

| Path | What |
|---|---|
| `packages/MarkdownEngine/` | Swift package: core engine (parse, layout, render, perf) |
| `apps/MarkdownApp/` | macOS AppKit application target |
| `agent_docs/` | Detailed architecture, conventions, and performance targets |
| `scripts/` | Build, test, and perf scripts |
| `fixtures/` | Test markdown files (small → large) |

## Core invariant

**Do not block typing.** The keystroke → text-storage path runs on the main thread with no parsing or layout work. All parsing, block diffing, layout, and preview rendering happen on a background actor and are cancelable. Stale results are discarded by revision check.

## Architecture (summary)

Edit → DocumentSnapshot → DirtyTracker → safe reparse region → parse (cmark-gfm) → BlockDiff → LayoutEngine → PreviewDiff → apply on main thread (revision-guarded)

See `agent_docs/architecture_overview.md` for the full pipeline and module responsibilities.

## Conventions

- Swift, AppKit, TextKit 1 for the editor
- cmark-gfm via C interop for parsing
- All background work is cancelable (last-write-wins)
- Measure everything with `os_signpost` (see `MarkdownPerf` module)
- See `agent_docs/conventions.md` for code style and naming rules

## Module boundaries

| Module | Responsibility | Dependencies |
|---|---|---|
| `MarkdownCore` | Document model, line index, dirty tracking, block types | Foundation |
| `MarkdownParse` | Parser abstraction + cmark-gfm wrapper, block building | MarkdownCore |
| `MarkdownLayout` | Block layout computation and caching | MarkdownCore |
| `MarkdownRender` | Preview diff and renderer backends (TextKit, CoreText) | MarkdownCore, MarkdownLayout |
| `MarkdownPerf` | os_signpost wrappers and performance counters | Foundation |
