#!/bin/bash
# Build Mac C++ target and copy required dependencies
# NOTE: Currently targets ARM64 (Apple Silicon) Macs only. Will not work on Intel Macs.
# Usage: ./scripts/build-mac.sh [project-dir]

set -e

if [ "$(uname -m)" != "arm64" ]; then
    echo "Error: This script only supports ARM64 (Apple Silicon) Macs."
    echo "Intel Mac support has not been implemented yet."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HAXEFMOD_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${1:-.}"

cd "$PROJECT_DIR"

echo "Building Mac C++ target..."
haxelib run lime build mac -64

# Find the .app bundle
APP_BUNDLE=$(find export -name "*.app" -path "*mac*" 2>/dev/null | head -1)
if [ -z "$APP_BUNDLE" ]; then
    echo "Error: Build output .app not found"
    exit 1
fi

APP_MACOS="$APP_BUNDLE/Contents/MacOS"

echo "Copying FMOD libraries to $APP_MACOS..."
cp "$HAXEFMOD_DIR/lib/Mac/api/core/lib/libfmod.dylib" "$APP_MACOS/"
cp "$HAXEFMOD_DIR/lib/Mac/api/studio/inc/lib/libfmodstudio.dylib" "$APP_MACOS/"

# Ensure rpath is set so the executable can find dylibs next to it
EXE=$(find "$APP_MACOS" -maxdepth 1 -type f -perm +111 ! -name "*.dylib" ! -name "*.ndll" -print | head -1)
if [ -n "$EXE" ]; then
    install_name_tool -add_rpath @executable_path "$EXE" 2>/dev/null || true
fi

echo "Build complete! Run with: open $(pwd)/$APP_BUNDLE"
