#!/bin/bash
# Builds Tazza.app (universal: Apple Silicon + Intel) without needing an Xcode project.
# Requirements: macOS 13+, Xcode Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# EDIT THESE before publishing: your GitHub username and your donation page.
# ---------------------------------------------------------------------------
GITHUB_USER="nsantullo"
REPO_URL="https://github.com/${GITHUB_USER}/Tazza"
DONATION_URL="https://ko-fi.com/nicolas92"   # or GitHub Sponsors / Buy Me a Coffee / PayPal.me
VERSION="1.0.0"
BUNDLE_ID="com.nicolasantullo.tazza"

APP="build/Tazza.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling (arm64 + x86_64)..."
FRAMEWORKS="-framework Cocoa -framework IOKit -framework ServiceManagement -framework UserNotifications"
swiftc Sources/*.swift -O -target arm64-apple-macos13.0 $FRAMEWORKS -o build/Tazza-arm64
swiftc Sources/*.swift -O -target x86_64-apple-macos13.0 $FRAMEWORKS -o build/Tazza-x86_64
lipo -create build/Tazza-arm64 build/Tazza-x86_64 -output "$APP/Contents/MacOS/Tazza"
rm build/Tazza-arm64 build/Tazza-x86_64

echo "Copying translations..."
for lang in Resources/*.lproj; do
  cp -R "$lang" "$APP/Contents/Resources/"
done

# Optional icon: put a square 1024x1024 PNG at Resources/AppIcon.png
ICON_KEY=""
if [ -f Resources/AppIcon.png ]; then
  echo "Building app icon..."
  ICONSET="build/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size*2)) $((size*2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Tazza</string>
  <key>CFBundleDisplayName</key><string>Tazza</string>
  <key>CFBundleExecutable</key><string>Tazza</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>it</string></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License. Made by Nicola Santullo.</string>
  <key>TazzaRepoURL</key><string>${REPO_URL}</string>
  <key>TazzaDonationURL</key><string>${DONATION_URL}</string>
  ${ICON_KEY}
</dict>
</plist>
PLIST

# Ad hoc signature: enough to run on your own Mac and to let "Launch at login" work.
# Distributing to other people without a Gatekeeper warning needs an Apple Developer ID + notarization.
codesign --force --deep --sign - "$APP"

echo "Done: $APP"
echo "Try it:  open $APP"
echo "Install: cp -R $APP /Applications/"
