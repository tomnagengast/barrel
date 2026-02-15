# Conventions

## Code Style

- Swift 5.9+, strict concurrency checking enabled
- Use `Sendable` where needed for cross-actor transfer
- Prefer value types (structs, enums) over classes on the hot path
- No force unwraps in production code (`!` is for tests and fatal precondition failures only)
- Use `precondition` / `preconditionFailure` for invariant violations, not `assert` (we want them in release builds)

## Naming

- Types: `UpperCamelCase`
- Functions, properties, locals: `lowerCamelCase`
- Module-public protocols end with a noun describing the capability (e.g., `MarkdownParser`, not `MarkdownParsing`)
- Keep file names matching the primary type they contain

## Module Rules

- `MarkdownCore` has zero dependencies beyond Foundation
- `MarkdownParse` depends only on `MarkdownCore` (and the C parser library)
- `MarkdownLayout` depends only on `MarkdownCore`
- `MarkdownRender` depends on `MarkdownCore` and `MarkdownLayout`
- `MarkdownPerf` depends only on Foundation/os
- The app target depends on all engine modules

Do not introduce cross-dependencies between `MarkdownParse`, `MarkdownLayout`, and `MarkdownRender` except through `MarkdownCore` types.

## Testing

- Every public type and function must have at least one unit test
- Use golden files in `fixtures/` for parser output verification
- Performance-sensitive code must have a benchmark in `MarkdownPerfTests`
- Test names: `test_<unit>_<scenario>_<expected>`
  - Example: `test_lineIndex_insertMiddle_updatesOffsets`

## Error Handling

- No `try?` to silently swallow errors in production code
- File I/O errors surface to the UI layer
- Parser errors produce a fallback plain-text block (never crash)

## Git

- One logical change per commit
- Commit message: imperative mood, < 72 chars first line
- Run `scripts/check.sh` before pushing
