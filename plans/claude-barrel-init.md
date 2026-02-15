# Barrel

## Core Philosophy

Carmack’s approach boils down to: do the simplest thing that could work, measure everything, eliminate waste. For a markdown editor that means minimizing layers of abstraction, avoiding frameworks that hide allocation patterns, and keeping the hot path (keystroke → re-parse → re-render) as tight as possible.

## Key Architectural Decisions

Language: Swift + AppKit (not SwiftUI)

SwiftUI’s declarative diffing is antithetical to the goal here. AppKit gives you direct control over the text system, and NSTextView is battle-tested for text editing. Swift gives you value types to avoid heap allocations on the hot path and easy interop with C libraries. No Electron, no WebView for rendering.

Parsing: cmark-gfm (C library) with incremental strategy

Don’t write your own parser — cmark is a state machine in C, it’s extremely fast, and it’s CommonMark-compliant. The real performance trick is incremental parsing: on each edit, only re-parse the affected block-level node (paragraph, list, code block), not the entire document. cmark’s AST makes this feasible — you track which byte ranges map to which AST nodes, and on edit you invalidate/re-parse only the dirty range plus surrounding context.

Text System: Custom NSTextStorage subclass

This is where the Carmack energy lives. NSTextStorage is the backbone of Cocoa’s text system. By subclassing it, you intercept every edit and can:
- Trigger incremental re-parse of only the changed region
- Apply syntax highlighting as attributed string changes in-place (no full re-render)
- Keep a parallel data structure mapping document ranges → cmark AST nodes

Rendering: NSTextView + NSLayoutManager (TextKit 1, not TextKit 2)

TextKit 2 is still buggy and less predictable. TextKit 1’s NSLayoutManager gives you fine-grained control over glyph generation and layout. For the preview pane (if you want one), render to NSAttributedString from the cmark AST — no WebView.

File I/O: Memory-mapped files

Use mmap for large files. No reason to read an entire 10MB markdown file into a heap buffer. The OS virtual memory system handles paging for free. For saves, use atomic writes (Data.write(to:options:.atomic)).

## Architecture Sketch
```
Keystroke
  → NSTextStorage.edited() (captures edit range + delta)
  → Incremental block invalidation (find affected AST node)
  → cmark re-parse of dirty block only
  → AST diff (old node vs new node)
  → Targeted attribute updates (syntax highlighting)
  → NSLayoutManager invalidates only affected glyph range
  →
```

The goal: a keystroke-to-
latency under 1ms for documents up to 100K lines.

## Component Breakdown

1. Document Model — A rope or gap buffer backing the raw text. Swift’s String is fine for moderate files, but for truly large files a rope data structure (tree of string chunks) gives you O(log n) insertions. Start with String, profile, upgrade if needed.
2. Block Map — An interval tree or sorted array mapping byte ranges to cmark AST block nodes. On edit, binary search to find affected blocks, mark dirty, re-parse only those.
3. Syntax Highlighter — Walks the cmark AST and maps node types to NSAttributedString attributes. Operates only on dirty ranges. No regex-based highlighting — the AST already tells you what everything is.
4. Preview Renderer (optional) — If you want a side-by-side preview, render from cmark AST → NSAttributedString in a second NSTextView (read-only). Not a WebView. This shares the same AST, so no double-parsing.
5. File Watcher — Use DispatchSource.makeFileSystemObjectSource for external change detection. Important for Obsidian-style vault workflows where other tools might modify the file.

## What to Skip (Scope Limits)

For v1, skip: extensions beyond GFM, collaborative editing, plugin system, custom themes (hardcode a good dark/light pair), image preview inline (just show the markdown syntax), and any kind of document tabs/project management. One file, one window, blazing fast.

## Build Plan



|Phase|Deliverable                                    |Focus                                                      |
|-----|-----------------------------------------------|-----------------------------------------------------------|
|0    |Swift package, cmark-gfm linked via C interop  |Build system, prove cmark works from Swift                 |
|1    |Custom NSTextStorage + basic NSTextView        |Raw editing, no highlighting yet, measure keystroke latency|
|2    |Full-document cmark parse → syntax highlighting|Get the AST → attributes pipeline working                  |
|3    |Incremental parsing (block invalidation)       |Only re-parse dirty blocks on edit                         |
|4    |Memory-mapped file I/O + large file testing    |Profile with 1MB+ markdown files                           |
|5    |Preview pane (AST → attributed string)         |Side-by-side, sharing the same AST                         |
|6    |Polish: find/replace, line numbers, minimap    |Quality of life                                            |

## Benchmarking from Day 1
Instrument from the very first commit. Key metrics to track on every change: keystroke-to-latency (target <1ms), full-document parse time, memory footprint per 1K lines, and time-to-first-on cold open. Use os_signpost for Instruments integration — it’s zero-cost when not profiling.

Want to start with Phase 0 — getting the Swift package scaffolded with cmark-gfm linked? Or do you want to debate any of these choices first? I’m particularly open to discussing whether a rope data structure is worth the complexity upfront vs. starting with String.​​​​​​​​​​​​​​​​