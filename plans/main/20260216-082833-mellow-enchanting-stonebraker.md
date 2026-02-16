# Plan: Make Barrel app buildable and runnable on macOS

## Context

The app can't build or run because:
1. **cmark-gfm not installed** — the `Ccmark` system library target can't find `cmark-gfm.h`
2. **No executable target** — `Package.swift` only defines library + test targets; `apps/MarkdownApp/Sources/` has 4 Swift files with a `@main` AppDelegate but no build target wires them in

## Steps

### 1. Install cmark-gfm

```bash
brew install cmark-gfm
```

### 2. Add executable target to `packages/MarkdownEngine/Package.swift`

Add to `products`:
```swift
.executable(name: "MarkdownApp", targets: ["MarkdownApp"]),
```

Add to `targets`:
```swift
.executableTarget(
    name: "MarkdownApp",
    dependencies: ["MarkdownCore", "MarkdownParse", "MarkdownLayout", "MarkdownRender", "MarkdownPerf"],
    path: "../../apps/MarkdownApp/Sources"
),
```

The `path` is relative to Package.swift's directory. The 4 source files (`AppDelegate.swift`, `EditorViewController.swift`, `LayoutCoordinator.swift`, `PreviewViewController.swift`) all import the engine modules and AppKit.

### 3. Build and run

```bash
cd packages/MarkdownEngine
swift build
swift run MarkdownApp
```

## Files modified

- `packages/MarkdownEngine/Package.swift` — add executable product + target

## Verification

1. `swift build` succeeds (warnings OK, no errors)
2. `swift run MarkdownApp` launches the Barrel window
3. `swift test` still passes (existing tests unaffected)
