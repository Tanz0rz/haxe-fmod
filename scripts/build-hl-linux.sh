#!/bin/bash
# Build script for HashLink on Linux
# Usage: ./scripts/build-hl-linux.sh [project-dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(cd "${1:-.}" && pwd)"
HLAXE_DIR="$ROOT_DIR/native/hlaxe"
FMOD_CORE="$ROOT_DIR/lib/Linux/api/core"
FMOD_STUDIO="$ROOT_DIR/lib/Linux/api/studio"

echo "=== Building hlaxe_fmod.hdll ==="
cd "$HLAXE_DIR"
gcc -shared -fPIC -O2 -o hlaxe_fmod.hdll hlaxe_fmod.c \
    -I/usr/include \
    -I"$FMOD_CORE/inc" \
    -I"$FMOD_STUDIO/inc" \
    -L"$FMOD_CORE/lib/x86_64" \
    -L"$FMOD_STUDIO/lib/x86_64" \
    -lfmod -lfmodstudio \
    -Wl,-rpath,'$ORIGIN'

echo "=== Building HL target ==="
cd "$PROJECT_DIR"
haxelib run lime build hl

BIN_DIR="$PROJECT_DIR/export/hl/bin"
if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Build output not found at $BIN_DIR"
    exit 1
fi

echo "=== Copying files to $BIN_DIR ==="
cp "$HLAXE_DIR/hlaxe_fmod.hdll" "$BIN_DIR/"
cp "$FMOD_CORE/lib/x86_64/libfmod.so.11" "$BIN_DIR/"
cp "$FMOD_STUDIO/lib/x86_64/libfmodstudio.so.11" "$BIN_DIR/"

# Create unversioned symlinks (HashLink dlopen needs .so, not .so.11)
cd "$BIN_DIR"
ln -sf libfmod.so.11 libfmod.so
ln -sf libfmodstudio.so.11 libfmodstudio.so

echo "=== Patching FMOD libraries (clearing execstack) ==="
if command -v patchelf &> /dev/null; then
    patchelf --clear-execstack libfmod.so.11 libfmodstudio.so.11
    echo "Patched successfully"
else
    echo "WARNING: patchelf not found. Install with: sudo apt install patchelf"
fi

echo "=== Creating run script ==="
EXE_NAME=$(find "$BIN_DIR" -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.hdll" ! -name "run.sh" -printf "%f\n" | head -1)
if [ -z "$EXE_NAME" ]; then
    EXE_NAME=$(ls "$BIN_DIR" | grep -E '^[A-Z]' | while read f; do [ -f "$BIN_DIR/$f" ] && [ ! -d "$BIN_DIR/$f" ] && echo "$f"; done | grep -v '\.' | head -1)
fi
cat > "$BIN_DIR/run.sh" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
export LD_LIBRARY_PATH="\$(pwd):\$LD_LIBRARY_PATH"
./$EXE_NAME "\$@"
EOF
chmod +x "$BIN_DIR/run.sh"

echo "=== Done ==="
echo "Run with: $BIN_DIR/run.sh"
