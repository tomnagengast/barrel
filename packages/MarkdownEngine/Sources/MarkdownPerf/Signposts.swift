import Foundation

#if canImport(os)
import os.signpost
#endif

// MARK: - MarkdownSignpost

/// Thin wrapper around `os_signpost` for profiling the edit-to-preview pipeline.
///
/// All signposts are zero-cost when not actively profiling with Instruments.
/// On Linux, all methods are no-ops.
public enum MarkdownSignpost {
    #if canImport(os)
    private static let log = OSLog(
        subsystem: "com.barrel.MarkdownEngine",
        category: "Pipeline"
    )
    #endif

    // MARK: - Pipeline Stages

    /// Main thread: recording an edit into DirtyTracker + LineIndex update.
    public static func beginEditCapture() {
        #if canImport(os)
        os_signpost(.begin, log: log, name: "EditCapture", signpostID: .exclusive)
        #endif
    }

    public static func endEditCapture() {
        #if canImport(os)
        os_signpost(.end, log: log, name: "EditCapture", signpostID: .exclusive)
        #endif
    }

    /// Dirty range expansion to safe reparse region.
    public static func beginDirtyExpand() {
        #if canImport(os)
        os_signpost(.begin, log: log, name: "DirtyExpand", signpostID: .exclusive)
        #endif
    }

    public static func endDirtyExpand() {
        #if canImport(os)
        os_signpost(.end, log: log, name: "DirtyExpand", signpostID: .exclusive)
        #endif
    }

    /// cmark-gfm parse of the reparse region.
    public static func beginParse() {
        #if canImport(os)
        os_signpost(.begin, log: log, name: "Parse", signpostID: .exclusive)
        #endif
    }

    public static func endParse() {
        #if canImport(os)
        os_signpost(.end, log: log, name: "Parse", signpostID: .exclusive)
        #endif
    }

    /// Diff old blocks vs new blocks.
    public static func beginBlockDiff() {
        #if canImport(os)
        os_signpost(.begin, log: log, name: "BlockDiff", signpostID: .exclusive)
        #endif
    }

    public static func endBlockDiff() {
        #if canImport(os)
        os_signpost(.end, log: log, name: "BlockDiff", signpostID: .exclusive)
        #endif
    }

    /// Layout computation for changed blocks.
    public static func beginLayout() {
        #if canImport(os)
        os_signpost(.begin, log: log, name: "Layout", signpostID: .exclusive)
        #endif
    }

    public static func endLayout() {
        #if canImport(os)
        os_signpost(.end, log: log, name: "Layout", signpostID: .exclusive)
        #endif
    }

    /// Main thread: applying PreviewDiff to the preview view.
    public static func beginPreviewApply() {
        #if canImport(os)
        os_signpost(.begin, log: log, name: "PreviewApply", signpostID: .exclusive)
        #endif
    }

    public static func endPreviewApply() {
        #if canImport(os)
        os_signpost(.end, log: log, name: "PreviewApply", signpostID: .exclusive)
        #endif
    }

    // MARK: - Events

    /// Log a single event with a message (for debugging, not profiling).
    public static func event(_ name: StaticString, _ message: String = "") {
        #if canImport(os)
        os_signpost(.event, log: log, name: name, "%{public}s", message)
        #endif
    }
}
