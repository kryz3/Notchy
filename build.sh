#!/bin/bash
set -e

APP_NAME="Notchy"
BUILD_DIR=".build"
APP_BUNDLE="${APP_NAME}.app"
MODE="${1:-debug}"

# Collect all Swift sources
SOURCES=$(find Sources -name "*.swift" | sort)

echo "Building ${APP_NAME} (${MODE})..."

# Compiler flags
FLAGS=(
    -target arm64-apple-macosx14.0
    -sdk $(xcrun --show-sdk-path)
    -framework AppKit
    -framework SwiftUI
    -framework EventKit
    -o "${BUILD_DIR}/${APP_NAME}"
)

if [ "$MODE" = "release" ]; then
    FLAGS+=(-O -whole-module-optimization)
else
    FLAGS+=(-g -Onone)
fi

mkdir -p "${BUILD_DIR}"
swiftc "${FLAGS[@]}" $SOURCES

# Create .app bundle
echo "Creating ${APP_BUNDLE}..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/"
codesign --force --sign - "${APP_BUNDLE}"

echo "Done! Run with: open ${APP_BUNDLE}"
