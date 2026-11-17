#!/bin/bash
# usage: scripts/lint.sh [--staged]   lints all tracked Swift files, or the staged version of staged ones
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root"

list=$(mktemp)
trap 'rm -rf "$list" "${snapshot:-}"' EXIT
if [ "${1:-}" = "--staged" ]; then
  git diff --cached --name-only -z --diff-filter=ACMR -- '*.swift' > "$list"
  [ -s "$list" ] || { echo "lint: no staged Swift files"; exit 0; }
  snapshot=$(mktemp -d)
  xargs -0 git checkout-index --prefix="$snapshot/" -- < "$list"
  cd "$snapshot"
else
  git ls-files -z -- '*.swift' > "$list"
  [ -s "$list" ] || { echo "lint: no Swift files"; exit 0; }
fi
for tool in swiftformat swiftlint; do
  command -v "$tool" >/dev/null || { echo "lint: $tool is not installed (brew install $tool)" >&2; exit 1; }
done
xargs -0 swiftformat --lint --config "$root/.swiftformat" < "$list"
xargs -0 swiftlint lint --strict --quiet --config "$root/.swiftlint.yml" < "$list"
