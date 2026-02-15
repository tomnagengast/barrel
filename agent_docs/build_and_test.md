# Build and Test

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+ with Swift 5.9+
- cmark-gfm installed via Homebrew: `brew install cmark-gfm`

## Building

### Engine package only
```bash
cd packages/MarkdownEngine
swift build
```

### Full app
```bash
xcodebuild -project apps/MarkdownApp/MarkdownApp.xcodeproj -scheme MarkdownApp build
```

## Testing

### Unit tests
```bash
scripts/test.sh
# or directly:
cd packages/MarkdownEngine && swift test
```

### Performance smoke tests
```bash
scripts/perf_smoke.sh
```
This runs against fixtures in `fixtures/` and reports parse time, layout time, and memory.

### Full check (format + lint + build + test)
```bash
scripts/check.sh
```

## Test structure

| Test target | What it covers |
|---|---|
| `MarkdownCoreTests` | LineIndex math, DirtyTracker coalescing, DocumentSnapshot |
| `MarkdownParseTests` | Parser output against golden fixtures, block builder |
| `MarkdownLayoutTests` | Layout computation, cache hit/miss behavior |
| `MarkdownPerfTests` | Benchmark harness for parse and layout timing |

## Adding fixtures

Place markdown files in `fixtures/`. Name them descriptively:
- `small_50kb.md` — typical document
- `large_1mb.md` — stress test
- `large_10mb.md` — extreme stress test
- `pathological_lists.md` — deeply nested lists
- `fenced_blocks.md` — many code fences

Tests reference these by path relative to the repo root.
