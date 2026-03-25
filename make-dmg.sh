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

# Create a styled DMG
echo "Creating DMG..."

# First create a read-write DMG
DMG_RW="release/${APP_NAME}_rw.dmg"
hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDRW \
    -size 50m \
    "${DMG_RW}"

# Mount it to apply styling
MOUNT_DIR="/Volumes/${VOL_NAME}"
hdiutil attach "${DMG_RW}" -mountpoint "${MOUNT_DIR}" -quiet

# Apply Finder styling via AppleScript
osascript << 'APPLESCRIPT'
tell application "Finder"
    tell disk "Notchy"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, 720, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        -- Position icons
        set position of item "Notchy.app" of container window to {140, 140}
        set position of item "Applications" of container window to {380, 140}
        close
    end tell
end tell
APPLESCRIPT

# Set background color via .DS_Store will be created by Finder
sync
sleep 1

# Unmount
hdiutil detach "${MOUNT_DIR}" -quiet

# Convert to compressed read-only DMG
hdiutil convert "${DMG_RW}" -format UDZO -o "${DMG_NAME}" -quiet
rm -f "${DMG_RW}"

# Clean temp
rm -rf "${DMG_TEMP}"

echo ""
echo "Done! ${DMG_NAME} created."
