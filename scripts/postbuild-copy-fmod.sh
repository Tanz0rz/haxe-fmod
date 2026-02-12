#!/bin/bash
# Post-build script to copy FMOD shared libraries to lime's output directory.
# Called automatically by lime via <postbuild> in include.xml.
# Usage: postbuild-copy-fmod.sh <platform> <target>
#   platform: mac, linux, or windows
#   target: cpp or hl

set -e

PLATFORM="$1"
TARGET="$2"

if [ -z "$FMOD_SDK" ]; then
  echo ""
  echo "============================================================"
  echo "  ERROR: FMOD_SDK environment variable is not set."
  echo ""
  echo "  Your build will NOT work without FMOD libraries!"
  echo "  You will see: Failed to load library hlaxe_fmod.hdll"
  echo "============================================================"
  echo ""
  echo "  haxe-fmod requires you to supply your own FMOD Engine SDK."
  echo ""
  echo "  1. Download FMOD Engine from https://www.fmod.com/download"
  echo "     - All platforms: version 2.03.12"
  echo ""
  echo "  2. Extract it and set FMOD_SDK to point to the extracted directory."
  echo "     The simplest place to store this would be at the root level of your project."
  echo ""
  echo "     export FMOD_SDK=/path/to/your-project/fmod-sdk"
  echo ""
  echo "     Expected layout:"
  echo "       \$FMOD_SDK/mac/api/core/inc/fmod.h"
  echo "       \$FMOD_SDK/linux/api/core/inc/fmod.h"
  echo "       \$FMOD_SDK/windows/api/core/inc/fmod.h"
  echo ""
  echo "  3. Run 'haxelib run haxefmod doctor' to verify your setup."
  echo ""
  echo "============================================================"
  echo ""
  exit 1
fi

case "$PLATFORM" in
  mac)
    SDK_DIR="$FMOD_SDK/mac"
    # Find .app bundle in export directory
    if [ "$TARGET" = "hl" ]; then
      APP_DIR=$(find export -path "*/hl/*" -name "*.app" -type d 2>/dev/null | head -1)
    else
      APP_DIR=$(find export -name "*.app" -path "*mac*" -type d 2>/dev/null | head -1)
    fi
    if [ -z "$APP_DIR" ]; then
      echo "[haxefmod postbuild] No .app bundle found in export/ - skipping FMOD lib copy"
      exit 0
    fi
    DEST="$APP_DIR/Contents/MacOS"
    echo "[haxefmod postbuild] Copying FMOD dylibs to $DEST"
    cp "$SDK_DIR/api/core/lib/libfmod.dylib" "$DEST/"
    cp "$SDK_DIR/api/studio/lib/libfmodstudio.dylib" "$DEST/"

    # Ensure rpath is set so the executable finds dylibs next to it
    EXE=$(find "$DEST" -maxdepth 1 -type f -perm +111 ! -name "*.dylib" ! -name "*.ndll" ! -name "*.hdll" -print 2>/dev/null | head -1)
    if [ -n "$EXE" ]; then
      install_name_tool -add_rpath @executable_path "$EXE" 2>/dev/null || true
    fi
    echo "[haxefmod postbuild] Done - copied libfmod.dylib and libfmodstudio.dylib"
    ;;
  linux)
    SDK_DIR="$FMOD_SDK/linux"
    # Find the bin directory in export
    if [ "$TARGET" = "hl" ]; then
      BIN_DIR=$(find export -path "*/hl/bin" -type d 2>/dev/null | head -1)
    else
      BIN_DIR=$(find export -path "*/linux*/bin" -type d 2>/dev/null | head -1)
    fi
    if [ -z "$BIN_DIR" ]; then
      echo "[haxefmod postbuild] No bin directory found in export/ - skipping FMOD lib copy"
      exit 0
    fi
    DEST="$BIN_DIR"
    echo "[haxefmod postbuild] Copying FMOD shared libraries to $DEST"
    cp "$SDK_DIR/api/core/lib/x86_64/libfmod.so" "$DEST/"
    cp "$SDK_DIR/api/core/lib/x86_64/libfmod.so.11" "$DEST/"
    cp "$SDK_DIR/api/studio/lib/x86_64/libfmodstudio.so" "$DEST/"
    cp "$SDK_DIR/api/studio/lib/x86_64/libfmodstudio.so.11" "$DEST/"

    # Create run.sh wrapper that sets LD_LIBRARY_PATH (if it doesn't exist)
    if [ ! -f "$DEST/run.sh" ]; then
      EXE_NAME=$(find "$DEST" -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.hdll" ! -name "run.sh" -printf '%f\n' 2>/dev/null | head -1)
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
  windows)
    SDK_DIR="$FMOD_SDK/windows"
    # Find the bin directory in export
    if [ "$TARGET" = "hl" ]; then
      BIN_DIR=$(find export -path "*/hl/bin" -type d 2>/dev/null | head -1)
    else
      BIN_DIR=$(find export -type d -name "bin" -path "*windows*" 2>/dev/null | head -1)
    fi
    if [ -z "$BIN_DIR" ]; then
      echo "[haxefmod postbuild] No bin directory found in export/ - skipping FMOD lib copy"
      exit 0
    fi
    DEST="$BIN_DIR"
    echo "[haxefmod postbuild] Copying FMOD DLLs to $DEST"
    cp "$SDK_DIR/api/core/lib/x64/fmod.dll" "$DEST/"
    cp "$SDK_DIR/api/studio/lib/x64/fmodstudio.dll" "$DEST/"
    echo "[haxefmod postbuild] Done - copied fmod.dll and fmodstudio.dll"
    ;;
  *)
    echo "[haxefmod postbuild] Unknown platform: $PLATFORM (expected mac, linux, or windows)"
    exit 1
    ;;
esac
