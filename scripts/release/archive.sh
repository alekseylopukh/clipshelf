#!/bin/bash
# usage: scripts/release/archive.sh <version> <build-number>
# archives a Release build and exports Clipsy.app with a Developer ID; DRY_RUN=1 keeps the ad-hoc signature
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

version="${1:-}"
build="${2:-}"
check_version "$version"
check_build_number "$build"

settings=(MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build")
if ! is_dry_run; then
  require_env DEVELOPER_ID_APPLICATION APPLE_TEAM_ID SPARKLE_PUBLIC_ED_KEY
  settings+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
  )
fi
if [ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]; then
  settings+=(SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY")
fi

archive="$release_dir/Clipsy.xcarchive"
rm -rf "$release_dir"
mkdir -p "$release_dir"

log "archiving Clipsy $version ($build)"
xcodebuild -project "$root/Clipsy.xcodeproj" -scheme Clipsy -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$derived_data" \
  -archivePath "$archive" -quiet archive "${settings[@]}"

if is_dry_run; then
  log "dry run: copying the ad-hoc signed app out of the archive"
  ditto "$archive/Products/Applications/Clipsy.app" "$app"
else
  log "exporting with the Developer ID method"
  options="$release_dir/ExportOptions.plist"
  plutil -create xml1 "$options"
  plutil -insert method -string developer-id "$options"
  plutil -insert signingStyle -string manual "$options"
  plutil -insert teamID -string "$APPLE_TEAM_ID" "$options"
  plutil -insert signingCertificate -string "Developer ID Application" "$options"
  xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
    -exportPath "$release_dir/export" -quiet
  ditto "$release_dir/export/Clipsy.app" "$app"
  rm -rf "$release_dir/export" "$options"
fi

[ "$(info_value CFBundleShortVersionString)" = "$version" ] || die "exported app has the wrong version"
[ "$(info_value CFBundleVersion)" = "$build" ] || die "exported app has the wrong build number"
codesign --verify --deep --strict "$app"
log "exported $app"
