#!/bin/bash
set -euo pipefail

APP_NAME="HelloNotch"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

echo "Building release binary..."
swift build -c release

echo "Creating ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"

mkdir -p "${CONTENTS}/Library/LaunchAgents"
cat > "${CONTENTS}/Library/LaunchAgents/com.hellonotch.app.launcher.plist" << 'AGENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hellonotch.app.launcher</string>
    <key>KeepAlive</key>
    <dict>
        <key>Crashed</key>
        <true/>
    </dict>
</dict>
</plist>
AGENT

echo "Generating AppIcon.icns..."
ICON_SRC="Resource/icon.png"
ICONSET="${CONTENTS}/Resources/AppIcon.iconset"
mkdir -p "${ICONSET}"
# Standard macOS icon sizes (no 512@2x — not needed outside App Store)
declare -a SIZES=("16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" "512:512x512")
for entry in "${SIZES[@]}"; do
    px="${entry%%:*}"
    name="${entry##*:}"
    sips -z "$px" "$px" "${ICON_SRC}" --out "${ICONSET}/icon_${name}.png" > /dev/null
done
# Compress with pngquant (lossy, ~70% smaller)
pngquant --quality=65-85 --force --ext .png "${ICONSET}"/*.png
iconutil -c icns "${ICONSET}" -o "${CONTENTS}/Resources/AppIcon.icns"
rm -rf "${ICONSET}"

cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HelloNotch</string>
    <key>CFBundleIdentifier</key>
    <string>com.hellonotch.app</string>
    <key>CFBundleName</key>
    <string>HelloNotch</string>
    <key>CFBundleDisplayName</key>
    <string>HelloNotch</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "Creating DMG..."
DMG_NAME="${APP_NAME}.dmg"
DMG_TEMP="dmg-staging"
rm -rf "${DMG_TEMP}" "${DMG_NAME}"
mkdir -p "${DMG_TEMP}"
cp -r "${APP_BUNDLE}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${DMG_NAME}" > /dev/null
rm -rf "${DMG_TEMP}"

echo "Done!"
echo "  ${APP_BUNDLE}  — app bundle"
echo "  ${DMG_NAME}    — installer DMG"
