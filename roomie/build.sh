#!/bin/bash
# Builds Roomie.app next to this script: one Swift file, no Xcode project. Needs the Command Line Tools.
set -e
cd "$(dirname "$0")"
APP=Roomie.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
# one binary for Apple silicon and Intel, from macOS 13 up
TMP="$(mktemp -d)"
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $ARCH-apple-macos13.0 main.swift -o "$TMP/Roomie-$ARCH" -framework AppKit -framework IOKit -framework ServiceManagement
done
lipo -create "$TMP/Roomie-arm64" "$TMP/Roomie-x86_64" -output "$APP/Contents/MacOS/Roomie"
# the icon is drawn by the app itself, then cut to the sizes macOS wants
mkdir -p "$APP/Contents/Resources"
ICONSET="$(mktemp -d)/Roomie.iconset"; mkdir -p "$ICONSET"
"$APP/Contents/MacOS/Roomie" --icon "$ICONSET/icon_512x512@2x.png" >/dev/null
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); [ $s -lt 512 ] && sips -z $d $d "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Roomie.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Roomie</string>
  <key>CFBundleIdentifier</key><string>local.roomie.probe</string>
  <key>CFBundleExecutable</key><string>Roomie</string>
  <key>CFBundleIconFile</key><string>Roomie</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.9</string>
  <key>CFBundleVersion</key><string>8</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAudioCaptureUsageDescription</key><string>Roomie listens to the sound your Mac plays only to find the beat and dance to it. Nothing is recorded or sent anywhere.</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP" >/dev/null 2>&1 || true
echo "built $APP"
