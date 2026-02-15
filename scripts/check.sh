#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_DIR="$REPO_ROOT/packages/MarkdownEngine"

echo "=== Barrel: Full Check ==="

# Step 1: Build the engine package
echo ""
echo "--- Building MarkdownEngine ---"
cd "$ENGINE_DIR"
swift build 2>&1
echo "Build: OK"

# Step 2: Run tests
echo ""
echo "--- Running Tests ---"
swift test 2>&1
echo "Tests: OK"

echo ""
echo "=== All checks passed ==="
