import Foundation
import os.signpost

// MARK: - MarkdownSignpost

/// Thin wrapper around `os_signpost` for profiling the edit-to-preview pipeline.
///
/// All signposts are zero-cost when not actively profiling with Instruments.
/// The log category "MarkdownEngine" groups all spans together.
public enum MarkdownSignpost {
    private static let log = OSLog(
        subsystem: "com.barrel.MarkdownEngine",
        category: "Pipeline"
    )

    // MARK: - Pipeline Stages

    /// Main thread: recording an edit into DirtyTracker + LineIndex update.
    public static func beginEditCapture(_ id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: log, name: "EditCapture", signpostID: id)
    }

    public static func endEditCapture(_ id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: log, name: "EditCapture", signpostID: id)
    }

    /// Dirty range expansion to safe reparse region.
    public static func beginDirtyExpand(_ id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: log, name: "DirtyExpand", signpostID: id)
    }

    public static func endDirtyExpand(_ id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: log, name: "DirtyExpand", signpostID: id)
    }

    /// cmark-gfm parse of the reparse region.
    public static func beginParse(_ id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: log, name: "Parse", signpostID: id)
    }

    public static func endParse(_ id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: log, name: "Parse", signpostID: id)
    }

    /// Diff old blocks vs new blocks.
    public static func beginBlockDiff(_ id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: log, name: "BlockDiff", signpostID: id)
    }

    public static func endBlockDiff(_ id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: log, name: "BlockDiff", signpostID: id)
    }

    /// Layout computation for changed blocks.
    public static func beginLayout(_ id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: log, name: "Layout", signpostID: id)
    }

    public static func endLayout(_ id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: log, name: "Layout", signpostID: id)
    }

    /// Main thread: applying PreviewDiff to the preview view.
    public static func beginPreviewApply(_ id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: log, name: "PreviewApply", signpostID: id)
    }

    public static func endPreviewApply(_ id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: log, name: "PreviewApply", signpostID: id)
    }

    // MARK: - Events

    /// Log a single event with a message (for debugging, not profiling).
    public static func event(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
}
