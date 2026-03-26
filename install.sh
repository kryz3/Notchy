#!/bin/bash
set -e

APP_NAME="Notchy"
INSTALL_DIR="/Applications"

echo "=== Notchy Installer ==="
echo ""

# Build if needed
if [ ! -d "${APP_NAME}.app" ]; then
    echo "Building ${APP_NAME}..."
    bash build.sh release
fi

# Kill running instance
pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
sleep 0.5

# Copy to /Applications
echo "Installing to ${INSTALL_DIR}..."
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
cp -R "${APP_NAME}.app" "${INSTALL_DIR}/"

# Remove quarantine flag (prevents "malware" warning)
echo "Removing quarantine flag..."
xattr -cr "${INSTALL_DIR}/${APP_NAME}.app"

echo "Setting up launch at login..."
# Create LaunchAgent
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="${PLIST_DIR}/com.notchy.app.plist"
mkdir -p "$PLIST_DIR"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.notchy.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>${INSTALL_DIR}/${APP_NAME}.app</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "Done! Notchy installed to ${INSTALL_DIR}/${APP_NAME}.app"
echo "It will start automatically at login."
echo ""
echo "Launching..."
open "${INSTALL_DIR}/${APP_NAME}.app"
