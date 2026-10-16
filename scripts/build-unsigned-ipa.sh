#!/usr/bin/env bash
# Build an UNSIGNED Quicksilver IPA locally on a Mac, for SideStore to re-sign on install.
# No signing, no secrets, no CI. See docs/SIDESTORE.md.
#
#   scripts/build-unsigned-ipa.sh                       # xcodegen + archive from source (Release)
#   scripts/build-unsigned-ipa.sh --archive X.xcarchive # package an existing archive
#   scripts/build-unsigned-ipa.sh --app Quicksilver.app # package an existing device .app
#   options: --out DIR (default build/ipa), --configuration Debug|Release
set -euo pipefail

OUT="build/ipa"; CONFIG="Release"; ARCHIVE=""; APP=""
die() { echo "error: $*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive) ARCHIVE="${2:?}"; shift 2 ;;
    --app) APP="${2:?}"; shift 2 ;;
    --out) OUT="${2:?}"; shift 2 ;;
    --configuration) CONFIG="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ "$(uname)" == "Darwin" ]] || die "run this on a Mac with Xcode"
[[ -z "$ARCHIVE" || -z "$APP" ]] || die "pass --archive or --app, not both"
mkdir -p "$OUT"

if [[ -z "$ARCHIVE" && -z "$APP" ]]; then
  command -v xcodegen >/dev/null || die "install XcodeGen (brew install xcodegen)"
  xcodegen generate
  ARCHIVE="$OUT/Quicksilver.xcarchive"
  rm -rf "$ARCHIVE"
  xcodebuild -project Quicksilver.xcodeproj -scheme Quicksilver -configuration "$CONFIG" \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" archive
fi
if [[ -n "$ARCHIVE" ]]; then
  [[ -d "$ARCHIVE/Products/Applications" ]] || die "not an xcarchive: $ARCHIVE"
  APP=$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' | head -1)
fi
[[ -n "$APP" && -d "$APP" ]] || die "no .app found"

PLIST="$APP/Info.plist"
[[ -f "$PLIST" ]] || die "missing Info.plist in $APP"
PLATFORMS=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms' "$PLIST" 2>/dev/null || true)
grep -q iPhoneOS <<<"$PLATFORMS" || die "$APP is not a device build (simulator .app can't go in an IPA)"
NAME=$(basename "$APP")
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || echo unknown)
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || echo unknown)

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
ditto "$APP" "$STAGE/Payload/$NAME"
# Strip any leftover signature or profile so SideStore signs from a clean slate.
rm -rf "$STAGE/Payload/$NAME/_CodeSignature" "$STAGE/Payload/$NAME/embedded.mobileprovision"

IPA="$(cd "$OUT" && pwd)/Quicksilver-${VERSION}-${BUILD}-unsigned.ipa"
rm -f "$IPA"
(cd "$STAGE" && /usr/bin/zip -qry "$IPA" Payload)
unzip -l "$IPA" | grep -q "Payload/$NAME/Info.plist" || die "IPA layout check failed"

echo "IPA:     $IPA"
echo "Version: $VERSION ($BUILD), commit $(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
echo "SHA-256: $(shasum -a 256 "$IPA" | cut -d' ' -f1)"
echo "Unsigned. Install with SideStore (docs/SIDESTORE.md)."
