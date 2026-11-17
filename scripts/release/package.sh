#!/bin/bash
# usage: scripts/release/package.sh <version>
# zips the exported app for Sparkle and builds a signed DMG with an Applications link
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

version="${1:-}"
check_version "$version"
[ -d "$app" ] || die "no exported app at $app; run archive.sh first"
identity=$(signing_identity)

zip=$(zip_path "$version")
log "zipping $(basename "$zip")"
rm -f "$zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

dmg=$(dmg_path "$version")
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Clipsy.app"
ln -s /Applications "$stage/Applications"
log "building $(basename "$dmg")"
rm -f "$dmg"
hdiutil create -quiet -volname Clipsy -srcfolder "$stage" -fs APFS -format UDZO "$dmg"
codesign --sign "$identity" --timestamp "$dmg"
codesign --verify "$dmg"
log "packaged $zip and $dmg"
