#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_DIR="$REPO_ROOT/packages/MarkdownEngine"

echo "=== Barrel: Unit Tests ==="

cd "$ENGINE_DIR"

# Run all test targets
swift test 2>&1

echo ""
echo "=== Tests complete ==="
