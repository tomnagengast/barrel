# Architecture Overview

## Core Idea

Treat Markdown preview as a list of independent blocks (paragraphs, headings, list items, code fences, quotes). Each block is:

- Identified by a stable `BlockID`
- Has a source `NSRange` in UTF-16 (to match AppKit)
- Can be laid out independently given a width constraint
- Can be cached independently

The preview view draws only visible blocks and re-lays out only blocks affected by an edit.

## Pipeline

```
Keystroke (main thread)
  → NSTextStorage.processEditing()
  → Record editedRange + changeInLength into DirtyTracker
  → Update LineIndex incrementally
  → Schedule background update (cancel any in-flight work)

Background actor (LayoutCoordinator)
  → Capture DocumentSnapshot (text + revision + lineIndex)
  → Expand dirty range to safe reparse region
  → Parse only that region (cmark-gfm)
  → Build new blocks, diff against existing BlockIndex
  → Layout only changed blocks
  → Produce PreviewDiff

Main thread (apply)
  → Guard: diff.revision == currentRevision
  → Splice changed blocks into preview
  → Invalidate only affected visible rects
```

## Module Responsibilities

### MarkdownCore
- `DocumentSnapshot`: Immutable view (text + revision + lineIndex) for background work
- `LineIndex`: Newline offsets in UTF-16 for fast line/range operations
- `DirtyTracker`: Coalesces edits, expands to safe reparse regions
- `BlockID` / `BlockModel` / `BlockKind`: Stable block identity and types

### MarkdownParse
- `MarkdownParser` protocol: Abstraction over concrete parser implementations
- `CmarkParser`: cmark-gfm wrapper via C interop
- `BlockBuilder`: Converts raw parse output into `[BlockModel]`

### MarkdownLayout
- `LayoutTypes`: `LayoutBlock`, `DrawPayload`, `LayoutKey`
- `LayoutEngine`: Computes layout for blocks given width + theme
- `LayoutCache`: Caches results keyed by `(BlockID, widthBucket, themeVariant, contentHash)`

### MarkdownRender
- `PreviewDiff`: Minimal diff to apply to the preview view
- `TextKitPreviewRenderer`: NSAttributedString-based preview (Stage 1)
- `CoreTextPreviewRenderer`: Custom CoreText tiled renderer (Stage 2, optional)

### MarkdownPerf
- `Signposts`: `os_signpost` wrappers for Instruments integration
- `PerfCounters`: Atomic counters for the in-app HUD

## Safe Reparse Region

Markdown is context-sensitive around lists, indentation, and fenced blocks. The dirty range must be expanded to a region guaranteed to reparse correctly:

1. Expand to full lines
2. Expand outward to nearest "hard boundaries":
   - Blank line not inside a continuation
   - Start/end of fenced code block
   - Heading line
   - Horizontal rule
3. If inside a fence, expand to the entire fence
4. Add a small safety margin (2-3 lines above and below)

## Concurrency Model

- `LayoutCoordinator` is a Swift actor
- Accepts edit events, coalesces dirty regions
- Runs one background pipeline job at a time (last-write-wins)
- Produces `PreviewDiff` guarded by revision number
- Main thread applies only if revision matches (no partial/stale apply)

## Two-Tier Preview Strategy

**Stage 1 (TextKit):** Read-only NSTextView with block-level attributed string splices. Fast to build, gets the pipeline working end-to-end.

**Stage 2 (CoreText):** Custom NSView with tiled rendering. Only draw visible blocks. Switch when TextKit preview becomes the bottleneck on large files.

Both backends share the same `BlockModel` and `LayoutBlock` types.
