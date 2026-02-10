#!/bin/bash
# Build script for HashLink on macOS
# NOTE: Currently targets ARM64 (Apple Silicon) Macs only. Will not work on Intel Macs.
# Usage: ./scripts/build-hl-mac.sh [project-dir]

set -e

if [ "$(uname -m)" != "arm64" ]; then
    echo "Error: This script only supports ARM64 (Apple Silicon) Macs."
    echo "Intel Mac support has not been implemented yet."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(cd "${1:-.}" && pwd)"
HLAXE_DIR="$ROOT_DIR/native/hlaxe"
FMOD_CORE="$ROOT_DIR/lib/Mac/api/core"
FMOD_STUDIO="$ROOT_DIR/lib/Mac/api/studio"

HL_PREFIX="$(brew --prefix hashlink)"

echo "=== Building hlaxe_fmod.hdll ==="
cd "$HLAXE_DIR"
cc -dynamiclib -arch x86_64 -O2 -o hlaxe_fmod.hdll hlaxe_fmod.c \
    -I"$HL_PREFIX/include" \
    -I"$FMOD_CORE/inc" \
    -I"$FMOD_STUDIO/inc" \
    -L"$FMOD_CORE/lib" \
    -L"$FMOD_STUDIO/inc/lib" \
    -lfmod -lfmodstudio \
    -install_name @executable_path/hlaxe_fmod.hdll

echo "=== Building HL target ==="
cd "$PROJECT_DIR"
haxelib run lime build hl

# Find the .app bundle
APP_BUNDLE=$(find export/hl -name "*.app" 2>/dev/null | head -1)
if [ -z "$APP_BUNDLE" ]; then
    echo "Error: Build output .app not found"
    exit 1
fi

APP_MACOS="$APP_BUNDLE/Contents/MacOS"

echo "=== Copying FMOD files to $APP_MACOS ==="
cp "$HLAXE_DIR/hlaxe_fmod.hdll" "$APP_MACOS/"
cp "$FMOD_CORE/lib/libfmod.dylib" "$APP_MACOS/"
cp "$FMOD_STUDIO/inc/lib/libfmodstudio.dylib" "$APP_MACOS/"

echo "=== Done ==="
echo "Run with: open $PROJECT_DIR/$APP_BUNDLE"
