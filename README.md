# Barrel

A native macOS Markdown editor with incremental live preview. Built with Swift, AppKit, and cmark-gfm.

## Overview

Barrel is a performance-focused Markdown editor designed around incremental parsing and rendering. Edits never block the main thread — parsing, block diffing, layout, and preview rendering all happen in a cancelable background pipeline.

## Architecture

- **Editor:** NSTextView with TextKit 1 for predictable text editing
- **Parser:** cmark-gfm (C library) with incremental region reparsing
- **Layout:** Block-level layout engine with per-block caching
- **Preview:** Read-only NSTextView with block-level attributed string splices (Stage 1), upgradeable to tiled CoreText renderer (Stage 2)

See [CLAUDE.md](CLAUDE.md) for build commands and module map, or [agent_docs/](agent_docs/) for detailed architecture docs.

## Quick Start

```bash
# Build and test the engine
cd packages/MarkdownEngine
swift build
swift test

# Full check (build + test)
scripts/check.sh
```

## Requirements

- macOS 14+ (Sonoma)
- Xcode 15+ / Swift 5.9+
- cmark-gfm (`brew install cmark-gfm`)
