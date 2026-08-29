#!/bin/bash
# Builds the Heaps example for one target and lays out a runnable directory.
# Usage: [BUILD_ROOT=dir] ./build.sh hl|hlc|js [-D audio_test ...]
# hl: "$B"/hl/game.hl plus the FMOD runtime and a launcher (run.sh, run.cmd on Windows)
# hlc: "$B"/hl/game, a native executable from the HL/C output (macOS)
# js: "$B"/html5/ served as a static site, open index.html?test=<state> for a test state
set -e
cd "$(dirname "$0")"
TARGET="$1"; shift
# Output root, so a game build and a test build can run side by side
B="${BUILD_ROOT:-build}"
case "$TARGET" in
  hl)
    # The hxml minus its output line, so the output root applies
    haxe $(grep -v '^#' build-hl.hxml | grep -v '^-hl ') "$@" -hl "$B/hl/game.hl"
    case "$(uname -s)" in
      Darwin*) PLATFORM=mac ;;
      MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
      *) PLATFORM=linux ;;
    esac
    haxelib run haxefmod stage "$PLATFORM" hl "$B"/hl
    if [ "$PLATFORM" = windows ]; then
      # HashLink's own packaging: hl.exe loads hlboot.dat from its directory
      # when started without arguments, so the copy gets the game's name
      # and the runtime DLL and hdlls sit next to it. Needs HASHLINK_DIR.
      : "${HASHLINK_DIR:?set HASHLINK_DIR to the HashLink installation}"
      cp "$HASHLINK_DIR"/hl.exe "$B"/hl/HeapsPlatformer.exe
      # The hdlls pull SDL2.dll and OpenAL32.dll from the same directory
      cp "$HASHLINK_DIR"/*.dll "$HASHLINK_DIR"/*.hdll "$B"/hl/ 2>/dev/null || true
      cp "$B"/hl/game.hl "$B"/hl/hlboot.dat
    fi
    rm -rf "$B"/hl/assets
    mkdir -p "$B"/hl/assets/fmod
    cp -r ../EZPlatformer/assets/fmod/Desktop "$B"/hl/assets/fmod/
    ;;
  hlc)
    # HL/C: the generated C compiled against an installed HashLink (libhl
    # plus its hdlls, Homebrew's on macOS) into a real executable, for
    # platforms without a HashLink VM. hlaxe_fmod.hdll comes from build-hdll
    # and must match the installed HashLink's architecture (see
    # HAXEFMOD_HDLL_ARCH).
    HL_PREFIX="${HASHLINK_PREFIX:-$(brew --prefix 2>/dev/null || echo /usr/local)}"
    rm -rf "$B"/hlc "$B"/hl
    mkdir -p "$B"/hlc "$B"/hl
    # The hxml minus its output line, redirected to C
    haxe $(grep -v '^#' build-hl.hxml | grep -v '^-hl ') "$@" -hl "$B"/hlc/main.c
    LIBS=""
    for lib in $(python3 -c "import json; print(' '.join(json.load(open('$B/hlc/hlc.json'))['libs']))"); do
      case "$lib" in
        std) ;;
        hlaxe_fmod) LIBS="$LIBS .haxefmod/hlaxe_fmod.hdll" ;;
        *) LIBS="$LIBS $HL_PREFIX/lib/$lib.hdll" ;;
      esac
    done
    # libuv is linked directly: the generated C calls its functions by name
    # for Heaps' networking natives
    clang -O2 -std=gnu11 -w -o "$B"/hl/game "$B"/hlc/main.c -I"$B"/hlc -I"$HL_PREFIX/include" \
      -L"$HL_PREFIX/lib" -lhl -luv $LIBS -Wl,-rpath,@executable_path -Wl,-rpath,"$HL_PREFIX/lib"
    haxelib run haxefmod stage mac hl "$B"/hl
    rm -rf "$B"/hl/assets
    mkdir -p "$B"/hl/assets/fmod
    cp -r ../EZPlatformer/assets/fmod/Desktop "$B"/hl/assets/fmod/
    ;;
  js)
    haxe $(grep -v '^#' build-js.hxml | grep -v '^-js ') "$@" -js "$B/html5/game.js"
    haxelib run haxefmod stage html5 html5 "$B"/html5/lib
    rm -rf "$B"/html5/assets
    mkdir -p "$B"/html5/assets/fmod
    cp -r ../EZPlatformer/assets/fmod/Desktop "$B"/html5/assets/fmod/
    cp index.html "$B"/html5/index.html
    ;;
  *)
    echo "usage: $0 hl|hlc|js [haxe args]"; exit 2 ;;
esac
