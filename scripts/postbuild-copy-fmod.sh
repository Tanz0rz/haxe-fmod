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
  echo ""
  echo "     export FMOD_SDK=/path/to/fmodstudioapi20312mac"
  echo ""
  echo "     Expected layout:"
  echo "       \$FMOD_SDK/api/core/inc/fmod.h"
  echo "       \$FMOD_SDK/api/studio/inc/fmod_studio.h"
  echo ""
  echo "     Note: Set FMOD_SDK to the extracted installer directory."
  echo "           Switch FMOD_SDK when building for different platforms."
  echo ""
  echo "  3. Run 'haxelib run haxefmod doctor' to verify your setup."
  echo ""
  echo "============================================================"
  echo ""
  exit 1
fi

# Verify FMOD SDK version matches what haxe-fmod was built against
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPECTED_VERSION_FILE="$SCRIPT_DIR/fmod_expected_version"
SDK_HEADER="$FMOD_SDK/api/core/inc/fmod_common.h"

# Convert hex to readable version (0x00020312 -> 0002.03.12)
hex_to_ver() {
  local hex=$((${1}))
  printf "%04x.%02x.%02x" $(( (hex >> 16) & 0xFFFF )) $(( (hex >> 8) & 0xFF )) $(( hex & 0xFF ))
}

if [ -f "$EXPECTED_VERSION_FILE" ] && [ -f "$SDK_HEADER" ]; then
  EXPECTED_VERSION=$(tr -d '[:space:]' < "$EXPECTED_VERSION_FILE")
  SDK_VERSION=$(grep '#define FMOD_VERSION' "$SDK_HEADER" | awk '{print $3}')

  if [ -n "$EXPECTED_VERSION" ] && [ -n "$SDK_VERSION" ] && [ "$EXPECTED_VERSION" != "$SDK_VERSION" ]; then
    echo ""
    echo "============================================================"
    echo "  ERROR: FMOD SDK version mismatch!"
    echo ""
    echo "  Your FMOD SDK:        $(hex_to_ver "$SDK_VERSION")"
    echo "  haxe-fmod expects:    $(hex_to_ver "$EXPECTED_VERSION")"
    echo ""
    echo "  Download the correct version from https://www.fmod.com/download"
    echo "============================================================"
    echo ""
    exit 1
  else
    echo "[haxefmod postbuild] FMOD SDK version $(hex_to_ver "$EXPECTED_VERSION") - OK"
  fi
else
  echo "[haxefmod postbuild] WARNING: Could not verify FMOD SDK version"
  [ ! -f "$EXPECTED_VERSION_FILE" ] && echo "[haxefmod postbuild]   Missing: $EXPECTED_VERSION_FILE"
  [ ! -f "$SDK_HEADER" ] && echo "[haxefmod postbuild]   Missing: $SDK_HEADER"
fi

case "$PLATFORM" in
  mac)
    SDK_DIR="$FMOD_SDK"
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

    # Copy hlaxe_fmod.hdll from templates (always, to ensure correct version)
    if [ "$TARGET" = "hl" ]; then
      HDLL_SRC="$SCRIPT_DIR/../templates/bin/hl/Mac64/hlaxe_fmod.hdll"
      if [ -f "$HDLL_SRC" ]; then
        cp "$HDLL_SRC" "$DEST/"
        echo "[haxefmod postbuild] Copied hlaxe_fmod.hdll"
      fi
    fi

    # Ensure rpath is set so the executable finds dylibs next to it
    EXE=$(find "$DEST" -maxdepth 1 -type f -perm +111 ! -name "*.dylib" ! -name "*.ndll" ! -name "*.hdll" -print 2>/dev/null | head -1)
    if [ -n "$EXE" ]; then
      install_name_tool -add_rpath @executable_path "$EXE" 2>/dev/null || true
    fi
    echo "[haxefmod postbuild] Done - copied libfmod.dylib and libfmodstudio.dylib"
    ;;
  linux)
    SDK_DIR="$FMOD_SDK"
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
    cp -P "$SDK_DIR/api/core/lib/x86_64/libfmod.so"* "$DEST/"
    cp -P "$SDK_DIR/api/studio/lib/x86_64/libfmodstudio.so"* "$DEST/"

    # Copy hlaxe_fmod.hdll from templates (always, to ensure correct version)
    if [ "$TARGET" = "hl" ]; then
      HDLL_SRC="$SCRIPT_DIR/../templates/bin/hl/Linux64/hlaxe_fmod.hdll"
      if [ -f "$HDLL_SRC" ]; then
        cp "$HDLL_SRC" "$DEST/"
        echo "[haxefmod postbuild] Copied hlaxe_fmod.hdll"
      fi
    fi

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
    SDK_DIR="$FMOD_SDK"
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
    # Copy hlaxe_fmod.hdll from templates (always, to ensure correct version)
    if [ "$TARGET" = "hl" ]; then
      HDLL_SRC="$SCRIPT_DIR/../templates/bin/hl/Windows64/hlaxe_fmod.hdll"
      if [ -f "$HDLL_SRC" ]; then
        cp "$HDLL_SRC" "$DEST/"
        echo "[haxefmod postbuild] Copied hlaxe_fmod.hdll"
      fi
    fi
    echo "[haxefmod postbuild] Done - copied fmod.dll and fmodstudio.dll"
    ;;
  html5)
    if [ -z "$FMOD_SDK_WEB" ]; then
      echo ""
      echo "============================================================"
      echo "  ERROR: FMOD_SDK_WEB environment variable is not set."
      echo ""
      echo "  HTML5 builds require the FMOD Engine SDK for HTML5."
      echo ""
      echo "  1. Download FMOD Engine 2.03.12 for HTML5 from:"
      echo "     https://www.fmod.com/download"
      echo ""
      echo "  2. Extract it and set FMOD_SDK_WEB:"
      echo ""
      echo "     export FMOD_SDK_WEB=/path/to/fmodstudioapi20312html5"
      echo ""
      echo "     Or on Windows:"
      echo "     set FMOD_SDK_WEB=C:\\path\\to\\fmodstudioapi20312html5"
      echo ""
      echo "  3. Run 'haxelib run haxefmod doctor' to verify your setup."
      echo ""
      echo "============================================================"
      echo ""
      exit 1
    fi

    SDK_DIR="$FMOD_SDK_WEB"
    # Find the HTML5 bin directory
    BIN_DIR=$(find export -path "*/html5/bin" -type d 2>/dev/null | head -1)
    if [ -z "$BIN_DIR" ]; then
      echo "[haxefmod postbuild] No html5/bin directory found - skipping FMOD file replacement"
      exit 0
    fi

    echo "[haxefmod postbuild] Replacing FMOD placeholder files with real SDK files"

    # Replace fmodstudio.js placeholder with real file (in lib/ subdirectory)
    if [ -f "$SDK_DIR/api/studio/lib/wasm/fmodstudio.js" ]; then
      mkdir -p "$BIN_DIR/lib"
      cp "$SDK_DIR/api/studio/lib/wasm/fmodstudio.js" "$BIN_DIR/lib/fmodstudio.js"
      echo "[haxefmod postbuild] Replaced fmodstudio.js"
    else
      echo "[haxefmod postbuild] ERROR: $SDK_DIR/api/studio/lib/wasm/fmodstudio.js not found"
      exit 1
    fi

    # Replace fmodstudio.wasm placeholder with real file
    if [ -f "$SDK_DIR/api/studio/lib/wasm/fmodstudio.wasm" ]; then
      cp "$SDK_DIR/api/studio/lib/wasm/fmodstudio.wasm" "$BIN_DIR/lib/fmodstudio.wasm"
      echo "[haxefmod postbuild] Replaced fmodstudio.wasm"
    else
      echo "[haxefmod postbuild] ERROR: $SDK_DIR/api/studio/lib/wasm/fmodstudio.wasm not found"
      exit 1
    fi

    echo "[haxefmod postbuild] Done - FMOD files ready for HTML5"
    ;;
  *)
    echo "[haxefmod postbuild] Unknown platform: $PLATFORM (expected mac, linux, windows, or html5)"
    exit 1
    ;;
esac
