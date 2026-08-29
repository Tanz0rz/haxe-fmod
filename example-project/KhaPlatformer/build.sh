#!/bin/bash
# Builds the Kha example for one target and lays out a runnable directory.
# Usage: KHA=/path/to/Kha ./build.sh linux|linux-hl|osx|osx-hl|windows|windows-hl|html5
#   linux, osx, windows:  Kore with hxcpp-generated C++, the binding compiled
#             from native/faxe/linc_faxe.cpp. Output build/<target>/, run
#             with run.sh (run.cmd on Windows)
#   *-hl:     Kore HL/C, the binding compiled from native/hlaxe/hlaxe_fmod.c.
#             Same layout
#   html5:    build/html5/ served as a static site, index.html?test=<state>
#             for a test state
# KHA_AUDIO_TEST=1 builds the test variant, KHA_MANUAL_UPDATE=1 the
# manual-update variant of it.
set -e
cd "$(dirname "$0")"
: "${KHA:?set KHA to the Kha checkout}"
TARGET="$1"
case "$TARGET" in
  linux|linux-hl|osx|osx-hl|windows|windows-hl)
    : "${FMOD_SDK:?set FMOD_SDK to the desktop FMOD Engine directory}"
    case "$TARGET" in
      linux*)   PLATFORM=linux; GRAPHICS="--graphics opengl"
                # kfile.js links -lfmod -lfmodstudio, so the linker needs the SDK's lib dirs
                export LIBRARY_PATH="$FMOD_SDK/api/core/lib/x86_64:$FMOD_SDK/api/studio/lib/x86_64${LIBRARY_PATH:+:$LIBRARY_PATH}" ;;
      osx*)     PLATFORM=mac; GRAPHICS="--graphics opengl"
                export LIBRARY_PATH="$FMOD_SDK/api/core/lib:$FMOD_SDK/api/studio/lib${LIBRARY_PATH:+:$LIBRARY_PATH}" ;;
      windows*) PLATFORM=windows; GRAPHICS="" ;;
    esac
    case "$TARGET" in *-hl) export HAXEFMOD_KHA_HL=1 ;; *) unset HAXEFMOD_KHA_HL ;; esac
    # The object directory goes too: kmake reuses objects across flag changes
    # (a graphics backend switch, for one) and links a broken binary from them
    rm -rf "build/$TARGET" "build/$TARGET-build"
    # Linux and macOS ask for OpenGL rather than Kinc's default Vulkan or
    # Metal: it runs on any display, a virtual or GPU-less one included.
    # Windows keeps Direct3D.
    node "$KHA/make.js" "$TARGET" --to build --compile $GRAPHICS
    OUT="build/$TARGET"
    mkdir -p "$OUT"
    # kmake writes the executable somewhere under the build tree, and the
    # depth differs per toolchain (Xcode and Visual Studio nest theirs)
    if [ "$PLATFORM" = windows ]; then
      EXE=$(find "build/$TARGET-build" -type f -name "KhaPlatformer.exe" | head -1)
    else
      EXE=$(find "build/$TARGET-build" -type f -perm -u+x -name "KhaPlatformer" | head -1)
    fi
    [ -n "$EXE" ] || { echo "no executable found under build/$TARGET-build"; exit 1; }
    cp "$EXE" "$OUT/KhaPlatformer$( [ "$PLATFORM" = windows ] && echo .exe )"
    haxelib run haxefmod stage "$PLATFORM" cpp "$OUT"
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
    echo "usage: $0 linux|linux-hl|osx|osx-hl|windows|windows-hl|html5"; exit 2 ;;
esac
