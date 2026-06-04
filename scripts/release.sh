#!/usr/bin/env bash
#
# Build a Release Burrow.app and package it as a distributable .zip, then
# print the sha256 for the Homebrew cask. The build is UNSIGNED — notarize
# separately (see scripts/notarize.sh notes) for a Gatekeeper-clean release.
#
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null 2>&1 || { echo "need xcodegen — brew install xcodegen"; exit 1; }

echo "==> xcodegen generate"
xcodegen generate >/dev/null

echo "==> building Release (unsigned)"
rm -rf build_dist
xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build_dist \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

APP="build_dist/Build/Products/Release/Burrow.app"
[ -d "$APP" ] || { echo "build failed: $APP missing"; exit 1; }

VERSION=$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)
mkdir -p dist
ZIP="dist/Burrow-$VERSION.zip"
rm -f "$ZIP"

echo "==> packaging $ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo
echo "Built Burrow $VERSION"
echo "  artifact : $ZIP"
echo "  sha256   : $SHA"
echo
echo "Publish:"
echo "  gh release create v$VERSION \"$ZIP\" --title \"Burrow $VERSION\" --notes-file RELEASES.md"
echo "  then set version=$VERSION + sha256=$SHA in packaging/burrow.rb (your tap)."
