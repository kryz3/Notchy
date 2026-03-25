#!/bin/bash

APP_NAME="Notchy"

echo "=== Notchy Uninstaller ==="

# Kill
pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# Remove app
rm -rf "/Applications/${APP_NAME}.app"
echo "Removed /Applications/${APP_NAME}.app"

# Remove LaunchAgent
rm -f "$HOME/Library/LaunchAgents/com.notchy.app.plist"
echo "Removed LaunchAgent"

# Remove preferences
defaults delete com.notchy.app 2>/dev/null || true
echo "Removed preferences"

# Remove log
rm -f "$HOME/.notchy.log"

echo ""
echo "Notchy uninstalled."
