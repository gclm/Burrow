#!/usr/bin/env bash
#
# build.sh — build Burrow.app with the MIT engine bundled AND properly sealed.
#
# The engine is staged into Resources by a build phase, but Xcode's CodeSign runs after all
# phases, leaving the resource seal stale (which breaks Full Disk Access — #177/#178). So the
# final inside-out seal is done HERE, after xcodebuild.
#
# Usage: scripts/build.sh [Debug|Release]
#   BURROW_ENGINE_SRC   engine checkout to bundle (default: ./vendor/burrow-engine)
#   BURROW_SIGN_IDENTITY signing identity (default: '-' ad-hoc; release sets a Developer ID)
set -euo pipefail
cd "$(dirname "$0")/.."   # macos/

CONFIG="${1:-Debug}"
ENGINE_SRC="${BURROW_ENGINE_SRC:-$PWD/vendor/burrow-engine}"
SIGN_ID="${BURROW_SIGN_IDENTITY:--}"

xcodegen generate >/dev/null

BURROW_ENGINE_SRC="$ENGINE_SRC" xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration "$CONFIG" CODE_SIGN_IDENTITY="$SIGN_ID" CODE_SIGNING_REQUIRED=NO build

APP="$(xcodebuild -project Burrow.xcodeproj -scheme Burrow -configuration "$CONFIG" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"

# Final inside-out seal (engine included). This is the step Xcode can't do for us.
codesign --force --deep --sign "$SIGN_ID" "$APP"
codesign --verify --deep "$APP" && echo "✓ built + sealed: $APP"
