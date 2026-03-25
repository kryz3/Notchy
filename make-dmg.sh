#!/bin/bash
set -e

APP_NAME="Notchy"
DMG_NAME="release/${APP_NAME}.dmg"
DMG_TEMP="dmg_temp"
VOL_NAME="${APP_NAME}"

echo "=== Building ${APP_NAME} DMG ==="

# Build release
echo "Building release..."
bash build.sh release

# Clean
mkdir -p release
rm -rf "${DMG_TEMP}" "${DMG_NAME}"

# Create temp folder with app + Applications symlink
mkdir -p "${DMG_TEMP}"
cp -R "${APP_NAME}.app" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

# Clean temp
rm -rf "${DMG_TEMP}"

echo ""
echo "Done! ${DMG_NAME} created."
echo "Users can open the DMG and drag Notchy.app to Applications."
