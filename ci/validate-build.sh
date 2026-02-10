#!/bin/bash
# Validate that a build output directory has all required files.
# Usage: ./ci/validate-build.sh <bin-dir> <target>
# target: "cpp" or "hl"
# Exits 0 if valid, 1 if validation fails.

BIN_DIR="$1"
TARGET="${2:-cpp}"

PASS=true

echo "=== Build Validation: $BIN_DIR ($TARGET) ==="
echo ""

# 1. Check bin dir exists
echo -n "  [1/5] Bin directory exists ......... "
if [ ! -d "$BIN_DIR" ]; then
  echo "FAIL (not found)"
  exit 1
fi
echo "OK"

# 2. Check executable exists
echo -n "  [2/5] Executable found ............. "
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  EXE=$(find "$BIN_DIR" -maxdepth 1 -name "*.exe" | head -1)
elif [ "$(uname -s)" = "Darwin" ]; then
  EXE=$(find "$BIN_DIR" -maxdepth 1 -type f -perm +111 ! -name "*.sh" ! -name "*.dylib" ! -name "*.hdll" | head -1)
else
  EXE=$(find "$BIN_DIR" -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.sh" ! -name "*.hdll" | head -1)
fi
if [ -z "$EXE" ]; then
  echo "FAIL (no executable in $BIN_DIR)"
  ls -la "$BIN_DIR"
  PASS=false
else
  echo "OK ($(basename "$EXE"))"
fi

# 3. Check FMOD libraries present
echo -n "  [3/5] FMOD libraries ............... "
FMOD_FOUND=true
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  [ -f "$BIN_DIR/fmod.dll" ] || FMOD_FOUND=false
  [ -f "$BIN_DIR/fmodstudio.dll" ] || FMOD_FOUND=false
elif [ "$(uname -s)" = "Darwin" ]; then
  [ -f "$BIN_DIR/libfmod.dylib" ] || FMOD_FOUND=false
  [ -f "$BIN_DIR/libfmodstudio.dylib" ] || FMOD_FOUND=false
else
  (ls "$BIN_DIR"/libfmod.so* 1>/dev/null 2>&1) || FMOD_FOUND=false
  (ls "$BIN_DIR"/libfmodstudio.so* 1>/dev/null 2>&1) || FMOD_FOUND=false
fi
if [ "$FMOD_FOUND" = false ]; then
  echo "FAIL (missing FMOD shared libraries)"
  PASS=false
else
  echo "OK"
fi

# 4. Check FMOD bank files present
echo -n "  [4/5] FMOD bank files .............. "
BANKS_DIR="$BIN_DIR/assets/fmod/Desktop"
# Mac .app bundles: assets are in Contents/Resources/, not Contents/MacOS/
if [ ! -d "$BANKS_DIR" ] && [[ "$BIN_DIR" == *Contents/MacOS* ]]; then
  RESOURCES_DIR="${BIN_DIR%/Contents/MacOS*}/Contents/Resources"
  BANKS_DIR="$RESOURCES_DIR/assets/fmod/Desktop"
fi
if [ -f "$BANKS_DIR/Master.bank" ] && [ -f "$BANKS_DIR/Master.strings.bank" ]; then
  MASTER_SIZE=$(stat -f%z "$BANKS_DIR/Master.bank" 2>/dev/null || stat -c%s "$BANKS_DIR/Master.bank" 2>/dev/null || wc -c < "$BANKS_DIR/Master.bank")
  echo "OK (Master.bank: ${MASTER_SIZE} bytes)"
else
  echo "FAIL (missing Master.bank or Master.strings.bank in $BANKS_DIR)"
  # Search broader for bank files
  SEARCH_ROOT="$BIN_DIR"
  [[ "$BIN_DIR" == *Contents/MacOS* ]] && SEARCH_ROOT="${BIN_DIR%/Contents/MacOS*}"
  FOUND_BANKS=$(find "$SEARCH_ROOT" -name "*.bank" 2>/dev/null | head -5)
  if [ -n "$FOUND_BANKS" ]; then
    echo "         Banks found elsewhere:"
    echo "$FOUND_BANKS"
  fi
  PASS=false
fi

# 5. Check manifest (lime asset library)
echo -n "  [5/5] Lime asset manifest .......... "
MANIFEST_DIR="$BIN_DIR/manifest"
# Mac .app bundles: manifest is in Contents/Resources/
if [ ! -d "$MANIFEST_DIR" ] && [ ! -f "$MANIFEST_DIR" ] && [[ "$BIN_DIR" == *Contents/MacOS* ]]; then
  MANIFEST_DIR="${BIN_DIR%/Contents/MacOS*}/Contents/Resources/manifest"
fi
if [ -d "$MANIFEST_DIR" ]; then
  echo "OK"
elif [ -f "$MANIFEST_DIR" ]; then
  echo "OK (file)"
else
  echo "WARN (no manifest directory — may still work)"
fi

echo ""
if [ "$PASS" = true ]; then
  echo "  RESULT: PASS"
else
  echo "  RESULT: FAIL"
  exit 1
fi
