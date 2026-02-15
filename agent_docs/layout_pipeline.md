# Layout Pipeline — Detailed Design

## Data Flow

```
DocumentSnapshot
  │
  ├── text: NSString
  ├── revision: Int
  └── lineIndex: LineIndex
          │
          ▼
    DirtyTracker
    (dirty NSRange → safe reparse region)
          │
          ▼
    MarkdownParser.parse(region)
    → [BlockModel] for region
          │
          ▼
    BlockDiff (old blocks vs new blocks)
    → removed: [BlockID]
    → inserted: [BlockModel]
    → updated: [BlockModel]
    → rangeShift: Int (for blocks after edit)
          │
          ▼
    LayoutEngine.layout(changedBlocks, width, theme)
    → [LayoutBlock] (only for changed blocks)
          │
          ▼
    PreviewDiff
    → revision: Int
    → removedIDs: [BlockID]
    → insertedLayouts: [(index, LayoutBlock)]
    → updatedLayouts: [LayoutBlock]
          │
          ▼
    Main thread: apply if revision matches
```

## BlockModel

```swift
struct BlockModel: Identifiable {
    let id: BlockID
    let kind: BlockKind
    var range: NSRange          // source range in UTF-16
    var inlines: [InlineSpan]   // for paragraph, heading, list item
    var metadata: BlockMetadata // heading level, fence lang, list depth, etc.
    var contentHash: UInt64     // hash of source slice
}
```

## LayoutBlock

```swift
struct LayoutBlock {
    let id: BlockID
    var measuredHeight: CGFloat
    var sourceRange: NSRange
    var drawPayload: DrawPayload
    var linkRects: [(NSRange, CGRect)]   // for click-to-jump
}
```

## DrawPayload

Backend-specific:
- **TextKit backend:** `NSAttributedString`
- **CoreText backend:** `CTFrame` + cached line metrics

```swift
enum DrawPayload {
    case textKit(NSAttributedString)
    case coreText(CTFrame, [LineMetric])
}
```

## Block Diff Algorithm

Given:
- `oldBlocks: [BlockModel]` in the reparse region
- `newBlocks: [BlockModel]` from fresh parse of that region

1. Match by `(kind, contentHash)` to identify unchanged blocks (preserve BlockID)
2. Remaining old blocks → removed
3. Remaining new blocks → inserted (assign new BlockID)
4. Blocks outside the reparse region → shift ranges by `changeInLength`

## Layout Cache

```
Key: (BlockID, widthBucket, themeVariant, contentHash)
Value: LayoutBlock
```

- `widthBucket` is `floor(width / 8)` to avoid relayout on tiny resize
- Cache is an LRU with configurable max entries
- On theme change, invalidate all entries (rare operation)

## Cancellation

The `LayoutCoordinator` actor holds:
- `currentRevision: Int` — incremented on every edit
- `activeTask: Task<Void, Never>?` — the current background pipeline run

On new edit:
1. Increment `currentRevision`
2. Cancel `activeTask`
3. Launch new task with captured revision
4. Inside task: check `Task.isCancelled` at each stage boundary
5. Produced `PreviewDiff` carries its revision; main thread discards if stale

## Height Prefix Sums

For fast scrolling in the custom CoreText view:
- Maintain `[CGFloat]` of cumulative block heights
- Binary search to find "which block is at scroll offset Y"
- Update only the affected range on block insert/remove/resize
