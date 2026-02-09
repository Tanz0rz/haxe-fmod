#!/bin/bash
# Build script for HashLink on Linux
# Run from the haxe-fmod root directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
HLAXE_DIR="$ROOT_DIR/native/hlaxe"
FMOD_CORE="$ROOT_DIR/lib/Linux/api/core"
FMOD_STUDIO="$ROOT_DIR/lib/Linux/api/studio"

# Output directory - passed as argument or default
OUTPUT_DIR="${1:-$ROOT_DIR/example-project/EZPlatformer/export/hl/bin}"

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

echo "=== Copying files to $OUTPUT_DIR ==="
mkdir -p "$OUTPUT_DIR"
cp "$HLAXE_DIR/hlaxe_fmod.hdll" "$OUTPUT_DIR/"
cp "$FMOD_CORE/lib/x86_64/libfmod.so.11" "$OUTPUT_DIR/"
cp "$FMOD_STUDIO/lib/x86_64/libfmodstudio.so.11" "$OUTPUT_DIR/"

echo "=== Patching FMOD libraries (clearing execstack) ==="
cd "$OUTPUT_DIR"
if command -v patchelf &> /dev/null; then
    patchelf --clear-execstack libfmod.so.11 libfmodstudio.so.11
    echo "Patched successfully"
else
    echo "WARNING: patchelf not found. Install it with: sudo pacman -S patchelf (or apt install patchelf)"
    echo "Without this, the game may fail to load on modern Linux kernels."
fi

echo "=== Creating run script ==="
cat > "$OUTPUT_DIR/run.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
export LD_LIBRARY_PATH="$(pwd):$LD_LIBRARY_PATH"
./EZPlatformer "$@"
EOF
chmod +x "$OUTPUT_DIR/run.sh"

echo "=== Done ==="
echo "Run with: cd $OUTPUT_DIR && ./run.sh"
