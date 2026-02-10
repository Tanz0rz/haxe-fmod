#!/bin/bash
# Post-build script to copy FMOD shared libraries to lime's C++ output directory.
# Called automatically by lime via <postbuild> in include.xml.
# Usage: postbuild-copy-fmod.sh <platform>
#   platform: mac or linux

set -e

PLATFORM="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HAXEFMOD_DIR="$(dirname "$SCRIPT_DIR")"

case "$PLATFORM" in
  mac)
    # Find .app bundle in export directory
    APP_DIR=$(find export -name "*.app" -type d 2>/dev/null | head -1)
    if [ -z "$APP_DIR" ]; then
      echo "[haxefmod postbuild] No .app bundle found in export/ - skipping FMOD lib copy"
      exit 0
    fi
    DEST="$APP_DIR/Contents/MacOS"
    echo "[haxefmod postbuild] Copying FMOD dylibs to $DEST"
    cp "$HAXEFMOD_DIR/lib/Mac/api/core/lib/libfmod.dylib" "$DEST/"
    cp "$HAXEFMOD_DIR/lib/Mac/api/studio/inc/lib/libfmodstudio.dylib" "$DEST/"

    # Ensure rpath is set so the executable finds dylibs next to it
    EXE=$(find "$DEST" -maxdepth 1 -type f -perm +111 ! -name "*.dylib" ! -name "*.ndll" -print 2>/dev/null | head -1)
    if [ -n "$EXE" ]; then
      install_name_tool -add_rpath @executable_path "$EXE" 2>/dev/null || true
    fi
    echo "[haxefmod postbuild] Done - copied libfmod.dylib and libfmodstudio.dylib"
    ;;
  linux)
    # Find the bin directory in export - could be linux/ or linux64/
    BIN_DIR=$(find export -path "*/linux*/bin" -type d 2>/dev/null | head -1)
    if [ -z "$BIN_DIR" ]; then
      echo "[haxefmod postbuild] No linux bin directory found in export/ - skipping FMOD lib copy"
      exit 0
    fi
    DEST="$BIN_DIR"
    echo "[haxefmod postbuild] Copying FMOD shared libraries to $DEST"
    cp "$HAXEFMOD_DIR/lib/Linux/api/core/lib/x86_64/libfmod.so" "$DEST/"
    cp "$HAXEFMOD_DIR/lib/Linux/api/core/lib/x86_64/libfmod.so.11" "$DEST/"
    cp "$HAXEFMOD_DIR/lib/Linux/api/studio/lib/x86_64/libfmodstudio.so" "$DEST/"
    cp "$HAXEFMOD_DIR/lib/Linux/api/studio/lib/x86_64/libfmodstudio.so.11" "$DEST/"

    # Create run.sh wrapper that sets LD_LIBRARY_PATH (if it doesn't exist)
    if [ ! -f "$DEST/run.sh" ]; then
      EXE_NAME=$(find "$DEST" -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "run.sh" -printf '%f\n' 2>/dev/null | head -1)
      if [ -n "$EXE_NAME" ]; then
        cat > "$DEST/run.sh" << RUNEOF
#!/bin/bash
cd "\$(dirname "\$0")"
export LD_LIBRARY_PATH="\$(pwd):\$LD_LIBRARY_PATH"
./$EXE_NAME "\$@"
RUNEOF
        chmod +x "$DEST/run.sh"
      fi
    fi
    echo "[haxefmod postbuild] Done - copied FMOD .so files"
    ;;
  *)
    echo "[haxefmod postbuild] Unknown platform: $PLATFORM (expected mac or linux)"
    exit 1
    ;;
esac
