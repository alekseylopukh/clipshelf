#!/bin/bash
# usage: scripts/release/appcast.sh <version>
# signs the zip with the Sparkle EdDSA key and adds it to the published appcast; writes appcast.xml
# DRY_RUN=1 starts from an empty feed instead of the published one
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

version="${1:-}"
check_version "$version"
require_env SPARKLE_PRIVATE_ED_KEY
zip=$(zip_path "$version")
[ -f "$zip" ] || die "no zip at $zip; run package.sh first"
sparkle_bin="$derived_data/SourcePackages/artifacts/sparkle/Sparkle/bin"
[ -x "$sparkle_bin/generate_appcast" ] || die "Sparkle tools not found in $sparkle_bin; run archive.sh first"

feed=$(info_value SUFeedURL)
[[ "$feed" == */releases/latest/download/appcast.xml ]] || die "SUFeedURL '$feed' is not a GitHub latest-release asset"
downloads="${feed%/latest/download/appcast.xml}/download/v$version/"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/feed"
cp "$zip" "$work/feed/"

if ! is_dry_run; then
  log "fetching the published appcast"
  code=$(curl -sSL -o "$work/feed/appcast.xml" -w '%{http_code}' "$feed")
  case "$code" in
    200) ;;
    404) log "no published appcast yet; starting a new one"; rm -f "$work/feed/appcast.xml" ;;
    *) die "fetching $feed failed with HTTP $code" ;;
  esac
fi

log "generating the appcast"
printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | "$sparkle_bin/generate_appcast" --ed-key-file - \
  --download-url-prefix "$downloads" --maximum-deltas 0 "$work/feed"
# generate_appcast only warns when the key does not match the app's SUPublicEDKey, and leaves the item unsigned
grep -F "$downloads$(basename "$zip")" "$work/feed/appcast.xml" | grep -q 'sparkle:edSignature=' ||
  die "the appcast item is unsigned: SPARKLE_PRIVATE_ED_KEY does not match the app's SUPublicEDKey"
cp "$work/feed/appcast.xml" "$release_dir/appcast.xml"
log "wrote $release_dir/appcast.xml"
