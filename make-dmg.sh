#!/bin/bash
# Packs build/Tazza.app into build/Tazza-<version>.dmg, with a link to drag it into Applications.
# Run ./build.sh first. Note that ./build.sh deletes the build folder, DMG included.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Tazza.app"
if [ ! -d "$APP" ]; then
  echo "Missing $APP: run ./build.sh first." >&2
  exit 1
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
DMG="build/Tazza-${VERSION}.dmg"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Tazza.app"
ln -s /Applications "$STAGE/Applications"

echo "Creating $DMG..."
hdiutil create -volname "Tazza" -srcfolder "$STAGE" -format UDZO -ov -quiet "$DMG"

echo "Done: $DMG"
