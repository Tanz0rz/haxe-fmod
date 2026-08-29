#!/bin/bash
# Builds the Kha example for one target and lays out a runnable directory.
# Usage: KHA=/path/to/Kha ./build.sh linux|linux-hl|html5
#   linux:    Kore with hxcpp-generated C++, the binding compiled from
#             native/faxe/linc_faxe.cpp. Output build/linux/, run with run.sh
#   linux-hl: Kore HL/C, the binding compiled from native/hlaxe/hlaxe_fmod.c.
#             Output build/linux-hl/, run with run.sh
#   html5:    build/html5/ served as a static site, index.html?test=<state>
#             for a test state
# KHA_AUDIO_TEST=1 builds the test variant, KHA_MANUAL_UPDATE=1 the
# manual-update variant of it.
set -e
cd "$(dirname "$0")"
: "${KHA:?set KHA to the Kha checkout}"
TARGET="$1"
case "$TARGET" in
  linux|linux-hl)
    : "${FMOD_SDK:?set FMOD_SDK to the desktop FMOD Engine directory}"
    # kfile.js links -lfmod -lfmodstudio, so the linker needs the SDK's lib dirs
    export LIBRARY_PATH="$FMOD_SDK/api/core/lib/x86_64:$FMOD_SDK/api/studio/lib/x86_64${LIBRARY_PATH:+:$LIBRARY_PATH}"
    if [ "$TARGET" = linux-hl ]; then export HAXEFMOD_KHA_HL=1; else unset HAXEFMOD_KHA_HL; fi
    # The object directory goes too: kmake reuses objects across flag changes
    # (a graphics backend switch, for one) and links a broken binary from them
    rm -rf "build/$TARGET" "build/$TARGET-build"
    # OpenGL rather than Kinc's default Vulkan: it runs on any display, a virtual one included
    node "$KHA/make.js" "$TARGET" --to build --compile --graphics opengl
    OUT="build/$TARGET"
    mkdir -p "$OUT"
    # kmake writes the executable into the debug directory of the target
    EXE=$(find "build/$TARGET-build" -maxdepth 2 -type f -executable -name "KhaPlatformer*" | head -1)
    [ -n "$EXE" ] || { echo "no executable found under build/$TARGET-build"; exit 1; }
    cp "$EXE" "$OUT/KhaPlatformer"
    haxelib run haxefmod stage linux cpp "$OUT"
    rm -rf "$OUT/assets"
    mkdir -p "$OUT/assets/fmod"
    cp -r ../EZPlatformer/assets/fmod/Desktop "$OUT/assets/fmod/"
    ;;
  html5)
    : "${FMOD_SDK_WEB:?set FMOD_SDK_WEB to the HTML5 FMOD Engine directory}"
    rm -rf build/html5
    mkdir -p build/html5
    # khamake only writes an index.html when none exists
    cp index.html build/html5/index.html
    node "$KHA/make.js" html5 --to build
    haxelib run haxefmod stage html5 html5 build/html5/lib
    rm -rf build/html5/assets
    mkdir -p build/html5/assets/fmod
    cp -r ../EZPlatformer/assets/fmod/Desktop build/html5/assets/fmod/
    ;;
  *)
    echo "usage: $0 linux|linux-hl|html5"; exit 2 ;;
esac
