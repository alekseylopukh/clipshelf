#!/bin/bash
# records that the currently staged tree passed review; the commit gate checks this marker
set -e
cd "$(git rev-parse --show-toplevel)"
tree=$(git write-tree)
dir="$(git rev-parse --git-dir)/review-passed"
mkdir -p "$dir"
date -u +%FT%TZ > "$dir/$tree"
echo "approved staged tree $tree"
