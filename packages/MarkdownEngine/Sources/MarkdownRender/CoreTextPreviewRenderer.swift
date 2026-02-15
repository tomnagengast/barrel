import Foundation
import MarkdownCore
import MarkdownLayout

// MARK: - CoreTextPreviewRenderer

/// Stage 2 preview renderer using a custom CoreText-based tiled view.
///
/// This is a placeholder for the future high-performance renderer.
/// It will replace the TextKit renderer when:
/// - Preview NSTextView starts dropping frames on large files
/// - Attributed string memory becomes dominant
/// - Strict viewport-only rendering control is needed
///
/// Design notes (for future implementation):
/// - Custom NSView inside NSScrollView
/// - Only draw blocks visible in the viewport (+ small overscan)
/// - Each block has a cached CTFrame or precomputed line breaks
/// - Block heights cached and stored as prefix sums for fast scroll offset lookup
/// - Tiled rendering: subdivide viewport into tiles, draw tiles on demand
///
/// The renderer shares the same BlockModel and LayoutBlock types as TextKitPreviewRenderer.

#if canImport(AppKit)
import AppKit

public final class CoreTextPreviewRenderer: PreviewRenderer {

    public init() {
        // Placeholder — will take an NSScrollView and configure a custom document view.
    }

    public func apply(diff: PreviewDiff) {
        // TODO: Implement tiled CoreText rendering
        // 1. Update block list from diff
        // 2. Invalidate tiles for changed blocks
        // 3. Redraw only visible tiles
    }

    public func replaceAll(layouts: [LayoutBlock]) {
        // TODO: Implement full replacement
        // 1. Clear all tiles
        // 2. Rebuild block list and height prefix sums
        // 3. Draw visible tiles
    }

    public func clear() {
        // TODO: Clear all tiles and block state
    }
}

#endif
