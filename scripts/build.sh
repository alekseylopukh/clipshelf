#!/bin/bash
# usage: scripts/build.sh [build|test]   build the app, or run the ClipsyKit tests
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
case "${1:-build}" in
  build)
    xcodebuild -project Clipsy.xcodeproj -scheme Clipsy -destination "platform=macOS,arch=$(uname -m)" \
      -derivedDataPath .build/DerivedData -quiet build ;;
  test)
    swift test --package-path Packages/ClipsyKit --quiet ;;
  *)
    echo "usage: scripts/build.sh [build|test]" >&2; exit 64 ;;
esac
