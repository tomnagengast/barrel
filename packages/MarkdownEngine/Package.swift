// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MarkdownEngine",
    platforms: [
        .macOS(.v14),  // macOS minimum for AppKit features; Linux builds ignore this.
    ],
    products: [
        .library(name: "MarkdownCore", targets: ["MarkdownCore"]),
        .library(name: "MarkdownParse", targets: ["MarkdownParse"]),
        .library(name: "MarkdownLayout", targets: ["MarkdownLayout"]),
        .library(name: "MarkdownRender", targets: ["MarkdownRender"]),
        .library(name: "MarkdownPerf", targets: ["MarkdownPerf"]),
        .executable(name: "MarkdownApp", targets: ["MarkdownApp"]),
    ],
    targets: [
        // MARK: - Core

        .target(
            name: "MarkdownCore",
            dependencies: [],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),

        // MARK: - Parse

        .systemLibrary(
            name: "Ccmark",
            pkgConfig: "libcmark-gfm",
            providers: [.brew(["cmark-gfm"]), .apt(["libcmark-gfm-dev"])]
        ),
        .target(
            name: "MarkdownParse",
            dependencies: ["MarkdownCore", "Ccmark"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),

        // MARK: - Layout

        .target(
            name: "MarkdownLayout",
            dependencies: ["MarkdownCore"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),

        // MARK: - Render

        .target(
            name: "MarkdownRender",
            dependencies: ["MarkdownCore", "MarkdownParse", "MarkdownLayout"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),

        // MARK: - Perf

        .target(
            name: "MarkdownPerf",
            dependencies: [],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),

        // MARK: - App

        .executableTarget(
            name: "MarkdownApp",
            dependencies: ["MarkdownCore", "MarkdownParse", "MarkdownLayout", "MarkdownRender", "MarkdownPerf"],
            path: "Sources/MarkdownApp"
        ),

        // MARK: - Tests

        .testTarget(
            name: "MarkdownCoreTests",
            dependencies: ["MarkdownCore"]
        ),
        .testTarget(
            name: "MarkdownParseTests",
            dependencies: ["MarkdownParse"]
        ),
        .testTarget(
            name: "MarkdownLayoutTests",
            dependencies: ["MarkdownLayout", "MarkdownCore"]
        ),
        .testTarget(
            name: "MarkdownPerfTests",
            dependencies: ["MarkdownParse", "MarkdownLayout", "MarkdownCore", "MarkdownPerf"]
        ),
    ]
)
