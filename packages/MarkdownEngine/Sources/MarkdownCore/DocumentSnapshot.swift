import Foundation

// MARK: - DocumentSnapshot

/// An immutable snapshot of the document state.
///
/// Created on the main thread and handed to background work.
/// Because `NSString` is immutable (and bridged `String` copies on mutation),
/// the snapshot is safe to read from any thread.
///
/// `NSString` is not annotated as `Sendable` in Foundation, so we opt into
/// `@unchecked Sendable` after auditing that this type stores immutable data.
public struct DocumentSnapshot: @unchecked Sendable {
    /// The full document text. UTF-16 indexed to match AppKit's `NSRange`.
    public let text: NSString
    /// Monotonically increasing generation counter. Every edit increments this.
    public let revision: Int
    /// Precomputed line-start offsets in UTF-16 units.
    public let lineIndex: LineIndex

    public init(text: NSString, revision: Int, lineIndex: LineIndex) {
        self.text = text
        self.revision = revision
        self.lineIndex = lineIndex
    }

    /// The length of the text in UTF-16 code units.
    public var length: Int { text.length }

    /// Extract the substring for the given `NSRange`.
    public func substring(with range: NSRange) -> String {
        precondition(
            range.location >= 0 && NSMaxRange(range) <= text.length,
            "Range \(range) out of bounds for text of length \(text.length)"
        )
        return text.substring(with: range)
    }
}
