#!/bin/bash
# Build Linux C++ target and copy required dependencies
# Usage: ./scripts/build-linux.sh [project-dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HAXEFMOD_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${1:-.}"

cd "$PROJECT_DIR"

echo "Building Linux C++ target..."
haxelib run lime build linux -64

# Find the output bin directory
BIN_DIR="export/linux64/bin"
if [ ! -d "$BIN_DIR" ]; then
    BIN_DIR="export/linux/bin"
fi
if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Build output not found"
    exit 1
fi

echo "Copying FMOD libraries..."
cp "$HAXEFMOD_DIR/lib/Linux/api/core/lib/x86_64/libfmod.so" "$BIN_DIR/"
cp "$HAXEFMOD_DIR/lib/Linux/api/core/lib/x86_64/libfmod.so.11" "$BIN_DIR/"
cp "$HAXEFMOD_DIR/lib/Linux/api/studio/lib/x86_64/libfmodstudio.so" "$BIN_DIR/"
cp "$HAXEFMOD_DIR/lib/Linux/api/studio/lib/x86_64/libfmodstudio.so.11" "$BIN_DIR/"

# Create run script if it doesn't exist
if [ ! -f "$BIN_DIR/run.sh" ]; then
    echo "Creating run script..."
    EXE_NAME=$(ls "$BIN_DIR" | grep -E '^[A-Z]' | grep -v '\.' | head -1)
    cat > "$BIN_DIR/run.sh" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
export LD_LIBRARY_PATH="\$(pwd):\$LD_LIBRARY_PATH"
./$EXE_NAME "\$@"
EOF
    chmod +x "$BIN_DIR/run.sh"
fi

echo "Build complete! Run with: $BIN_DIR/run.sh"
