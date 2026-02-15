#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_DIR="$REPO_ROOT/packages/MarkdownEngine"
FIXTURES_DIR="$REPO_ROOT/fixtures"

echo "=== Barrel: Performance Smoke Tests ==="

# Build in release mode for meaningful perf numbers
echo ""
echo "--- Building in release mode ---"
cd "$ENGINE_DIR"
swift build -c release 2>&1

# Run perf test target
echo ""
echo "--- Running perf tests ---"
swift test --filter MarkdownPerfTests 2>&1

# Report fixture sizes
echo ""
echo "--- Fixture files ---"
if [ -d "$FIXTURES_DIR" ]; then
    ls -lh "$FIXTURES_DIR"/*.md 2>/dev/null || echo "No .md fixtures found"
else
    echo "Fixtures directory not found"
fi

echo ""
echo "=== Perf smoke complete ==="
