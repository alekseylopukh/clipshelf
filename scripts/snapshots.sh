#!/bin/bash
# usage: scripts/snapshots.sh [dir]   renders the Shelf offscreen to PNGs (default .build/snapshots)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
mkdir -p "${1:-.build/snapshots}"
out=$(cd "${1:-.build/snapshots}" && pwd)
CLIPSY_SNAPSHOTS="$out" swift test --package-path Packages/ClipsyKit --quiet --filter ShelfSnapshotTests
ls "$out"/*.png
