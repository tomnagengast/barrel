# Barrel — macOS Markdown Editor

A native macOS AppKit Markdown editor with incremental live preview.

## Quick start

```bash
mise install          # install swiftformat, swiftlint, cmark-gfm
mise run check        # format + lint + build + test
mise run test         # unit tests only
mise run perf         # performance smoke tests
scripts/check.sh     # build + test (no mise required)
scripts/perf_smoke.sh # perf smoke tests (no mise required)
```

## Pre-commit

Pre-commit hooks are configured in `prek.toml` (uses [prek](https://prek.j178.dev)):
- Trailing whitespace, EOF fixer, large file check, merge conflict detection
- SwiftFormat lint, SwiftLint strict, Swift build

```bash
prek install          # install git hooks
prek run --all-files  # run hooks on all files
```

## Cloud environment (Claude Code web)

A SessionStart hook (`.claude/hooks/session-init.sh`) auto-installs Swift and cmark-gfm on Linux. On macOS the hook is a no-op. The engine builds and tests on both platforms — AppKit code is guarded behind `#if canImport(AppKit)` and compiles as stubs on Linux.

## Repo map

| Path | What |
|---|---|
| `packages/MarkdownEngine/` | Swift package: core engine (parse, layout, render, perf) |
| `apps/MarkdownApp/` | macOS AppKit application target |
| `agent_docs/` | Detailed architecture, conventions, and performance targets |
| `scripts/` | Build, test, and perf scripts |
| `fixtures/` | Test markdown files (small → large) |
| `.claude/` | SessionStart hook and project settings for Claude Code |

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
