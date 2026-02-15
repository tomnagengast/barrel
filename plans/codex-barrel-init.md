Below is a concrete, "drop it in the repo" set of Swift interfaces and diff types you can use as the stable seam between Parse, Layout, and Render. The intent is:

- One small shared contract that almost never changes (reduces agent merge conflicts)
- Pure, testable stages with explicit inputs and outputs (gives automated backpressure via tests and perf counters)
- Coalescing + cancellation + last-write-wins so the system stays responsive while typing (no unbounded queues)

I'm going to define:

1. Core types and diff format (`MarkdownCore`)
2. Protocols for Parse, Block diffing/ID assignment, Layout, Render (`MarkdownParse`, `MarkdownLayout`, `MarkdownRender`)
3. A coordinator actor contract that enforces backpressure and keeps edits non-blocking
4. A parallel-work map for agents (who edits what files)

---

## 1) Shared diff format and core types (`MarkdownCore`)

Put this in a single file like:

`packages/MarkdownEngine/Sources/MarkdownCore/MarkdownInterfaces.swift`

Keep it short, and treat it as "API surface". Additive changes only when possible.

```swift
import Foundation
import CoreGraphics

// MARK: - Revision and source edits

public typealias Revision = Int

/// A single edit to the source buffer in UTF-16 coordinates (AppKit-friendly).
public struct SourceEdit: Sendable, Hashable {
  public var revision: Revision
  public var range: NSRange          // edited range in pre-edit coordinates
  public var delta: Int              // change in UTF-16 length (postLen - preLen)

  public init(revision: Revision, range: NSRange, delta: Int) {
    self.revision = revision
    self.range = range
    self.delta = delta
  }
}

/// Immutable view used by background parse/layout work.
public struct DocumentSnapshot: Sendable {
  public var revision: Revision
  public var text: NSString
  public var lineIndex: LineIndex

  public init(revision: Revision, text: NSString, lineIndex: LineIndex) {
    self.revision = revision
    self.text = text
    self.lineIndex = lineIndex
  }
}

// MARK: - Line index (minimal contract, implementation elsewhere)

public struct LineIndex: Sendable, Hashable {
  /// Start offsets (UTF-16) for each line, including line 0 at offset 0.
  public var lineStarts: [Int]

  public init(lineStarts: [Int]) {
    self.lineStarts = lineStarts
  }
}

// MARK: - Block identity

public struct BlockID: Sendable, Hashable, CustomStringConvertible {
  public let rawValue: UInt64
  public init(_ rawValue: UInt64) { self.rawValue = rawValue }
  public var description: String { "BlockID(\(rawValue))" }
}

public struct BlockIDGenerator: Sendable {
  private var nextValue: UInt64 = 1
  public init() {}
  public mutating func next() -> BlockID {
    defer { nextValue &+= 1 }
    return BlockID(nextValue)
  }
}

// MARK: - Markdown model

public enum BlockKind: Sendable, Hashable {
  case paragraph
  case heading(level: Int)
  case blockQuote(depth: Int)
  case listItem(ordered: Bool, depth: Int)
  case codeFence(language: String?)
  case thematicBreak
}

public enum InlineKind: Sendable, Hashable {
  case text
  case emphasis
  case strong
  case code
  case link(destination: String)
}

/// Inline span local to a block. Offsets are UTF-16 relative to block.range.location.
public struct InlineSpan: Sendable, Hashable {
  public var localRange: Range<Int>
  public var kind: InlineKind

  public init(localRange: Range<Int>, kind: InlineKind) {
    self.localRange = localRange
    self.kind = kind
  }
}

/// A parser output that does not yet have stable IDs assigned.
public struct BlockDraft: Sendable, Hashable {
  public var kind: BlockKind
  public var range: NSRange                 // UTF-16 in document coordinates
  public var inlines: [InlineSpan]          // for text-like blocks (can be empty)
  public var contentHash: UInt64            // hash of relevant content + metadata

  public init(kind: BlockKind, range: NSRange, inlines: [InlineSpan], contentHash: UInt64) {
    self.kind = kind
    self.range = range
    self.inlines = inlines
    self.contentHash = contentHash
  }
}

/// Canonical block model used downstream (layout/render). Has stable identity.
public struct BlockModel: Sendable, Hashable {
  public var id: BlockID
  public var kind: BlockKind
  public var range: NSRange
  public var inlines: [InlineSpan]
  public var contentHash: UInt64

  public init(id: BlockID, kind: BlockKind, range: NSRange, inlines: [InlineSpan], contentHash: UInt64) {
    self.id = id
    self.kind = kind
    self.range = range
    self.inlines = inlines
    self.contentHash = contentHash
  }
}

// MARK: - Block list and splices (the diff format)

/// The canonical ordered block list for the current document revision.
public struct BlockList: Sendable {
  public var revision: Revision
  public var blocks: [BlockModel]

  public init(revision: Revision, blocks: [BlockModel]) {
    self.revision = revision
    self.blocks = blocks
  }
}

/// A splice replaces a contiguous range of blocks (by index) with new blocks.
/// This stays simple and is easy for renderers to apply efficiently.
public struct BlockSplice: Sendable, Hashable {
  public var replacedRange: Range<Int>     // indices into the old BlockList.blocks
  public var newBlocks: [BlockModel]       // ordered

  public init(replacedRange: Range<Int>, newBlocks: [BlockModel]) {
    self.replacedRange = replacedRange
    self.newBlocks = newBlocks
  }
}

/// Parse stage output to update the block list.
public struct BlockChangeSet: Sendable, Hashable {
  public var revision: Revision
  public var reparsedSourceRange: NSRange  // the source region that was reparsed
  public var removedIDs: [BlockID]
  public var splices: [BlockSplice]

  public init(
    revision: Revision,
    reparsedSourceRange: NSRange,
    removedIDs: [BlockID],
    splices: [BlockSplice]
  ) {
    self.revision = revision
    self.reparsedSourceRange = reparsedSourceRange
    self.removedIDs = removedIDs
    self.splices = splices
  }
}

// MARK: - Layout outputs

public struct ThemeKey: Sendable, Hashable {
  public var name: String
  public var isDark: Bool
  public init(name: String, isDark: Bool) {
    self.name = name
    self.isDark = isDark
  }
}

/// Quantize width to reduce cache churn during live resizing.
public struct WidthBucket: Sendable, Hashable {
  public var points: Int
  public init(points: Int) { self.points = points }

  public static func bucket(for width: CGFloat, quantum: CGFloat = 4) -> WidthBucket {
    let q = max(1, Int(quantum.rounded()))
    let bucketed = Int((width / CGFloat(q)).rounded()) * q
    return WidthBucket(points: max(1, bucketed))
  }
}

public struct LayoutEnvironment: Sendable, Hashable {
  public var theme: ThemeKey
  public var width: WidthBucket
  public var scale: CGFloat

  public init(theme: ThemeKey, width: WidthBucket, scale: CGFloat) {
    self.theme = theme
    self.width = width
    self.scale = scale
  }
}

/// Renderer-independent layout result.
/// For v1, use AttributedString (Sendable) as the draw payload.
/// A TextKit renderer can convert it to NSAttributedString per block.
public struct LayoutBlock: Sendable, Hashable {
  public var id: BlockID
  public var sourceRange: NSRange
  public var height: CGFloat
  public var attributed: AttributedString

  public init(id: BlockID, sourceRange: NSRange, height: CGFloat, attributed: AttributedString) {
    self.id = id
    self.sourceRange = sourceRange
    self.height = height
    self.attributed = attributed
  }
}

public struct LayoutChangeSet: Sendable, Hashable {
  public var revision: Revision
  public var env: LayoutEnvironment
  public var removedIDs: [BlockID]
  public var updated: [LayoutBlock]   // includes new and changed blocks

  public init(revision: Revision, env: LayoutEnvironment, removedIDs: [BlockID], updated: [LayoutBlock]) {
    self.revision = revision
    self.env = env
    self.removedIDs = removedIDs
    self.updated = updated
  }
}

/// Unified output the UI layer applies (last-write-wins by revision).
public struct PreviewDiff: Sendable, Hashable {
  public var revision: Revision
  public var blockChanges: BlockChangeSet
  public var layoutChanges: LayoutChangeSet

  public init(revision: Revision, blockChanges: BlockChangeSet, layoutChanges: LayoutChangeSet) {
    self.revision = revision
    self.blockChanges = blockChanges
    self.layoutChanges = layoutChanges
  }
}
```

### Why this diff format works well

- It is **splice-based** (contiguous replacements), so the renderer can update a backing store efficiently.
- It is **revisioned**, so stale diffs are safely discarded.
- It is **simple enough** that multiple agents can implement the stages independently without agreeing on complex move semantics.

---

## 2) Protocols for Parse, ID assignment/diff, Layout, Render

### Parse module contracts (`MarkdownParse`)

Files:
- `MarkdownParse/MarkdownParser.swift`
- `MarkdownParse/BlockDiffEngine.swift`

```swift
import Foundation
import MarkdownCore

// MARK: - Parse

public struct ParseRegion: Sendable, Hashable {
  public var requested: NSRange
  public var actual: NSRange   // parser may expand to safe boundaries

  public init(requested: NSRange, actual: NSRange) {
    self.requested = requested
    self.actual = actual
  }
}

public struct ParsedRegion: Sendable, Hashable {
  public var revision: Revision
  public var region: ParseRegion
  public var drafts: [BlockDraft]   // ordered by range.location

  public init(revision: Revision, region: ParseRegion, drafts: [BlockDraft]) {
    self.revision = revision
    self.region = region
    self.drafts = drafts
  }
}

/// Pure parser. No stable IDs, no dependency on existing BlockList.
/// This keeps it easy to swap cmark-gfm vs tree-sitter later.
public protocol MarkdownParser: Sendable {
  func parse(snapshot: DocumentSnapshot, region: NSRange) throws -> ParsedRegion
}

// MARK: - Draft-to-model and diff

/// Assign stable BlockIDs and produce a splice-based diff to update BlockList.
/// This stage owns the "preserve IDs where possible" logic.
public protocol BlockDiffing: Sendable {
  mutating func makeChangeSet(
    old: BlockList,
    parsed: ParsedRegion,
    idGen: inout BlockIDGenerator
  ) -> BlockChangeSet
}
```

### Layout module contracts (`MarkdownLayout`)

Files:
- `MarkdownLayout/BlockLayouter.swift`
- `MarkdownLayout/LayoutCache.swift`

```swift
import Foundation
import MarkdownCore

/// Converts BlockModel into LayoutBlock for a given environment.
/// Should be deterministic and cache-friendly.
public protocol BlockLayouter: Sendable {
  func layout(
    snapshot: DocumentSnapshot,
    block: BlockModel,
    env: LayoutEnvironment
  ) throws -> LayoutBlock
}

/// Applies layout only for blocks that changed, using caches.
/// This stage should be cheap to run repeatedly and supports cancellation.
public protocol LayoutComputing: Sendable {
  mutating func makeChangeSet(
    snapshot: DocumentSnapshot,
    blockList: BlockList,
    blockChanges: BlockChangeSet,
    env: LayoutEnvironment
  ) throws -> LayoutChangeSet
}
```

### Render module contracts (`MarkdownRender`)

Render is intentionally dumb: it applies diffs to a view or backing store.

Files:
- `MarkdownRender/PreviewRendering.swift`
- `MarkdownRender/TextKitPreviewRenderer.swift`
- *later* `MarkdownRender/CoreTextPreviewRenderer.swift`

```swift
import Foundation
import CoreGraphics
import MarkdownCore

/// Main-thread only. Renderers should not do parsing or heavy layout.
public protocol PreviewRendering: AnyObject {
  /// Apply the latest diff. Implementation must ignore stale diffs.
  func apply(diff: PreviewDiff)

  /// Optional, for click-to-jump. Return a UTF-16 source offset if possible.
  func sourceOffset(at pointInView: CGPoint) -> Int?
}
```

---

## 3) Coordinator contract that enforces backpressure and avoids wasted work

This is the piece that keeps typing smooth and prevents unbounded work queues. It also makes the system "agent-proof" because correctness is externally verifiable (tests, perf counters) and jobs are cancelable.

Files:
- `MarkdownRender/LayoutCoordinator.swift` (or `MarkdownEngine/PreviewPipelineCoordinator.swift`)

```swift
import Foundation
import MarkdownCore
import MarkdownParse
import MarkdownLayout

/// Coordinates parse and layout off-main, applies diffs on main.
/// Last-write-wins by revision.
public actor PreviewPipelineCoordinator {
  private let parser: any MarkdownParser
  private var differ: any BlockDiffing
  private var layouter: any LayoutComputing

  private var idGen = BlockIDGenerator()

  private var currentBlockList = BlockList(revision: 0, blocks: [])
  private var latestRequestedRevision: Revision = 0

  private var inFlightTask: Task<Void, Never>?

  public init(
    parser: any MarkdownParser,
    differ: any BlockDiffing,
    layouter: any LayoutComputing
  ) {
    self.parser = parser
    self.differ = differ
    self.layouter = layouter
  }

  /// Called by the editor on the main thread, but this method itself is actor-isolated.
  /// You pass a snapshot so parse/layout can run off-main safely.
  public func onEdit(
    snapshot: DocumentSnapshot,
    edit: SourceEdit,
    previewEnv: LayoutEnvironment,
    applyOnMain: @Sendable @escaping (PreviewDiff) -> Void
  ) {
    latestRequestedRevision = max(latestRequestedRevision, edit.revision)

    // Cancel previous work. Backpressure: keep only the newest desired output.
    inFlightTask?.cancel()

    inFlightTask = Task(priority: .userInitiated) { [parser] in
      do {
        try Task.checkCancellation()

        // 1) Decide region to parse (could be expanded by parser).
        // For v1, you can pass edit.range and let parser expand.
        let parsed = try parser.parse(snapshot: snapshot, region: edit.range)
        try Task.checkCancellation()

        // 2) Diff blocks: assign stable IDs, produce splice changes.
        let blockChanges = self.differ.makeChangeSet(
          old: self.currentBlockList,
          parsed: parsed,
          idGen: &self.idGen
        )
        try Task.checkCancellation()

        // 3) Apply block changes locally (actor state) to produce new BlockList.
        let newBlockList = Self.apply(blockChanges: blockChanges, to: self.currentBlockList)

        // 4) Layout only changed blocks for the current preview environment.
        let layoutChanges = try self.layouter.makeChangeSet(
          snapshot: snapshot,
          blockList: newBlockList,
          blockChanges: blockChanges,
          env: previewEnv
        )
        try Task.checkCancellation()

        let diff = PreviewDiff(revision: snapshot.revision, blockChanges: blockChanges, layoutChanges: layoutChanges)

        // Commit new block list only if still the latest requested revision.
        guard diff.revision == self.latestRequestedRevision else { return }
        self.currentBlockList = newBlockList

        // 5) Apply on main.
        await MainActor.run { applyOnMain(diff) }
      } catch {
        // v1: swallow errors (or log). Never crash the editor on malformed markdown.
      }
    }
  }

  private static func apply(blockChanges: BlockChangeSet, to old: BlockList) -> BlockList {
    precondition(blockChanges.revision >= old.revision)

    var blocks = old.blocks
    // Apply splices in descending order to keep indices valid.
    for splice in blockChanges.splices.sorted(by: { $0.replacedRange.lowerBound > $1.replacedRange.lowerBound }) {
      blocks.replaceSubrange(splice.replacedRange, with: splice.newBlocks)
    }
    return BlockList(revision: blockChanges.revision, blocks: blocks)
  }
}
```

### Why this matches the agent scaling guidance

- It is a **pipeline with distinct responsibilities** (parse, diff/ID assignment, layout, render), which is the same shape that helps multi-agent systems avoid churn and coordination failures.
- It **avoids lock-style coordination** and instead uses last-write-wins by revision, similar in spirit to optimistic coordination rather than holding locks.
- It **bakes in cancellation and bounded work**, preventing wasted effort while typing.

---

## 4) Responsibilities by stage (so agents do not step on each other)

This is the "who edits what" map. It mirrors the planner/worker separation pattern that scales better than flat collaboration.

### Shared API surface (edit rarely)

- `MarkdownCore/MarkdownInterfaces.swift`
- Owned by "architect" role
- Changes should be additive, small, and reviewed carefully

### Parser worker

- Implements `CmarkParser: MarkdownParser`
- Owns:
  - safe region expansion inside `parse(...)` (or a helper)
  - producing ordered `[BlockDraft]` with ranges and inline spans

### Block diff worker

- Implements `BlockDiffEngine: BlockDiffing`
- Owns:
  - mapping `BlockDraft` to stable `BlockModel`
  - preserving IDs where `contentHash` and `kind` match
  - producing `BlockChangeSet` with a small number of splices

### Layout worker

- Implements `TextLayoutEngine: LayoutComputing` and a cache
- Owns:
  - turning `BlockModel` + snapshot text slice into `AttributedString`
  - measuring height (CoreText measurement is fine here)
  - returning `LayoutChangeSet` only for changed/new blocks

### Renderer worker

- Implements `TextKitPreviewRenderer: PreviewRendering`
- Owns:
  - applying `PreviewDiff` on main thread
  - updating a view backing store per splice
  - ignoring stale diffs by revision

This setup encourages "verifiable goals" because each worker can be driven by unit tests and fixtures, not by subjective review.

---

## 5) Minimal test surfaces for each module (the backpressure you want)

The backpressure principle is: give the system automated ways to tell agents "wrong" early, so humans do not spend time on trivial feedback.

Suggested unit tests:

- **MarkdownParseTests**
  - golden fixtures: input markdown -> ordered drafts with ranges and kinds
- **BlockDiffEngineTests**
  - start with an old `BlockList`, apply a synthetic edit, feed parsed drafts, verify:
    - splices minimal
    - unchanged blocks keep same `BlockID`
- **MarkdownLayoutTests**
  - stable measurement for a fixed env width bucket and theme key
  - cache hit behavior: same `(id, env, hash)` yields no recompute
- **RendererTests**
  - apply a diff with splices and ensure backing store length and order match expected
  - revision gating: stale diffs are ignored

---

## 6) One note about `CLAUDE.md` / `AGENTS.md` for this repo

Since you're building agentically: keep the root agent instruction file short and universal, and push details into module docs (progressive disclosure). That reduces the chance the agent ignores it as irrelevant.

---

If you want, next I can sketch an initial `BlockDiffEngine` strategy (matching drafts to old blocks by overlapping range and `contentHash`) and a "safe reparse region" helper that is simple but correct for fences, blank-line boundaries, and headings.
