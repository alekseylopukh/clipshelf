#!/bin/bash
# usage: scripts/release/release.sh [--dry-run] <version> <build-number>
# runs every release step; outputs Clipsy-<version>.zip, Clipsy-<version>.dmg and appcast.xml in .build/release
# --dry-run signs ad-hoc, skips notarization, uses a throwaway Sparkle key and needs no secrets
here=$(dirname "$0")

if [ "${1:-}" = --dry-run ]; then
  export DRY_RUN=1
  shift
fi
# shellcheck source=lib.sh
source "$here/lib.sh"

version="${1:-}"
build="${2:-}"
check_version "$version"
check_build_number "$build"
if is_dry_run; then
  der=$(openssl genpkey -algorithm ed25519 -outform DER | base64)
  SPARKLE_PRIVATE_ED_KEY=$(base64 -d <<< "$der" | tail -c 32 | base64)
  SPARKLE_PUBLIC_ED_KEY=$(base64 -d <<< "$der" | openssl pkey -inform DER -pubout -outform DER | tail -c 32 | base64)
  export SPARKLE_PRIVATE_ED_KEY SPARKLE_PUBLIC_ED_KEY
else
  require_env DEVELOPER_ID_APPLICATION APPLE_TEAM_ID SPARKLE_PUBLIC_ED_KEY SPARKLE_PRIVATE_ED_KEY \
    NOTARY_KEY_PATH NOTARY_KEY_ID NOTARY_ISSUER_ID
fi

"$here/archive.sh" "$version" "$build"
"$here/notarize.sh" "$app"
"$here/package.sh" "$version"
"$here/notarize.sh" "$(dmg_path "$version")"
"$here/appcast.sh" "$version"
if ! is_dry_run; then
  spctl --assess --type execute "$app"
fi
log "release $version ($build) is ready in $release_dir"
