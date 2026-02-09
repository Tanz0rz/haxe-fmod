#!/bin/bash
# Build HashLink target and copy required dependencies
# Usage: ./scripts/build-hl.sh [project-dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HAXEFMOD_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${1:-.}"

cd "$PROJECT_DIR"

echo "Building HashLink target..."
haxelib run lime build hl

# Find the output bin directory
BIN_DIR="export/hl/bin"
if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Build output not found at $BIN_DIR"
    exit 1
fi

echo "Copying FMOD libraries..."
if [ "$(uname -s)" = "Darwin" ]; then
    cp "$HAXEFMOD_DIR/lib/Mac/api/core/lib/libfmod.dylib" "$BIN_DIR/"
    cp "$HAXEFMOD_DIR/lib/Mac/api/studio/inc/lib/libfmodstudio.dylib" "$BIN_DIR/"
else
    cp "$HAXEFMOD_DIR/lib/Linux/api/core/lib/x86_64/libfmod.so" "$BIN_DIR/"
    cp "$HAXEFMOD_DIR/lib/Linux/api/core/lib/x86_64/libfmod.so.11" "$BIN_DIR/"
    cp "$HAXEFMOD_DIR/lib/Linux/api/studio/lib/x86_64/libfmodstudio.so" "$BIN_DIR/"
    cp "$HAXEFMOD_DIR/lib/Linux/api/studio/lib/x86_64/libfmodstudio.so.11" "$BIN_DIR/"
fi

echo "Copying hlaxe_fmod.hdll..."
cp "$HAXEFMOD_DIR/native/hlaxe/hlaxe_fmod.hdll" "$BIN_DIR/"

# Create run script
echo "Creating run script..."
# Find executable (file without extension that is executable, not a directory)
EXE_NAME=$(find "$BIN_DIR" -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.hdll" ! -name "run.sh" -printf "%f\n" | head -1)
if [ -z "$EXE_NAME" ]; then
    # Fallback: look for capitalized name without extension
    EXE_NAME=$(ls "$BIN_DIR" | grep -E '^[A-Z]' | while read f; do [ -f "$BIN_DIR/$f" ] && [ ! -d "$BIN_DIR/$f" ] && echo "$f"; done | grep -v '\.' | head -1)
fi
cat > "$BIN_DIR/run.sh" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
export LD_LIBRARY_PATH="\$(pwd):\$LD_LIBRARY_PATH"
./$EXE_NAME "\$@"
EOF
chmod +x "$BIN_DIR/run.sh"

echo "Build complete! Run with: $BIN_DIR/run.sh"
