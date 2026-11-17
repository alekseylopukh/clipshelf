# shellcheck shell=bash
# sourced by the release scripts; never prints secret values, so never run them with set -x
set -euo pipefail

root=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
release_dir="${RELEASE_DIR:-$root/.build/release}"
# shellcheck disable=SC2034 # used by the scripts that source this file
derived_data="$root/.build/DerivedData"
app="$release_dir/Clipsy.app"
dry_run="${DRY_RUN:-0}"

log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

is_dry_run() { [ "$dry_run" = 1 ]; }

describe_env() {
  case "$1" in
    DEVELOPER_ID_APPLICATION) echo "Developer ID Application signing identity, for example 'Developer ID Application: Name (TEAMID)'" ;;
    APPLE_TEAM_ID) echo "Apple Developer team ID that owns the Developer ID certificate" ;;
    NOTARY_KEY_PATH) echo "path to the App Store Connect API key file (AuthKey_XXXXXXXXXX.p8)" ;;
    NOTARY_KEY_ID) echo "App Store Connect API key ID" ;;
    NOTARY_ISSUER_ID) echo "App Store Connect API issuer ID" ;;
    SPARKLE_PUBLIC_ED_KEY) echo "Sparkle EdDSA public key (base64), printed by Sparkle's generate_keys" ;;
    SPARKLE_PRIVATE_ED_KEY) echo "Sparkle EdDSA private key (base64), exported with Sparkle's generate_keys -x" ;;
  esac
}

# usage: require_env NAME...; reports every missing variable at once
require_env() {
  local name missing=()
  for name in "$@"; do
    [ -n "${!name:-}" ] || missing+=("  $name: $(describe_env "$name")")
  done
  [ ${#missing[@]} -eq 0 ] && return
  printf 'error: missing environment variables (see docs/architecture.md#64-release-pipeline):\n' >&2
  printf '%s\n' "${missing[@]}" >&2
  exit 1
}

check_version() {
  [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.2.3, got '${1:-}'"
}

check_build_number() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]] || die "build number must be a positive integer, got '${1:-}'"
}

info_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$app/Contents/Info.plist"
}

zip_path() { printf '%s/Clipsy-%s.zip' "$release_dir" "$1"; }
dmg_path() { printf '%s/Clipsy-%s.dmg' "$release_dir" "$1"; }

signing_identity() {
  if is_dry_run; then
    printf -- '-'
  else
    require_env DEVELOPER_ID_APPLICATION
    printf '%s' "$DEVELOPER_ID_APPLICATION"
  fi
}
