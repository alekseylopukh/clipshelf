#!/bin/bash
# usage: scripts/release/notarize.sh <Clipsy.app | Clipsy-x.y.z.dmg>
# submits to the notary service with an App Store Connect API key, waits, then staples the ticket
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

target="${1:-}"
[ -e "$target" ] || die "usage: notarize.sh <app or dmg>"
if is_dry_run; then
  log "dry run: skipping notarization of $(basename "$target")"
  exit 0
fi
require_env NOTARY_KEY_PATH NOTARY_KEY_ID NOTARY_ISSUER_ID
[ -f "$NOTARY_KEY_PATH" ] || die "NOTARY_KEY_PATH does not point to a file"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
upload="$target"
if [ -d "$target" ]; then
  upload="$work/$(basename "$target").zip"
  ditto -c -k --keepParent "$target" "$upload"
fi

log "notarizing $(basename "$target")"
xcrun notarytool submit "$upload" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" \
  --issuer "$NOTARY_ISSUER_ID" --wait --timeout 1h --output-format json > "$work/result.json"
status=$(plutil -extract status raw "$work/result.json")
if [ "$status" != Accepted ]; then
  id=$(plutil -extract id raw "$work/result.json")
  xcrun notarytool log "$id" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" >&2 || true
  die "notarization of $(basename "$target") ended with status '$status'"
fi

xcrun stapler staple "$target"
xcrun stapler validate "$target"
