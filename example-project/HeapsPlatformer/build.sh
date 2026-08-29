#!/bin/bash
# Builds the Heaps example for one target and lays out a runnable directory.
# Usage: ./build.sh hl|hlc|js [-D audio_test ...]
# hl: build/hl/game.hl plus the FMOD runtime and a launcher (run.sh, run.cmd on Windows)
# hlc: build/hl/game, a native executable from the HL/C output (macOS)
# js: build/html5/ served as a static site, open index.html?test=<state> for a test state
set -e
cd "$(dirname "$0")"
TARGET="$1"; shift
case "$TARGET" in
  hl)
    haxe build-hl.hxml "$@"
    case "$(uname -s)" in
      Darwin*) PLATFORM=mac ;;
      MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
      *) PLATFORM=linux ;;
    esac
    haxelib run haxefmod stage "$PLATFORM" hl build/hl
    if [ "$PLATFORM" = windows ]; then
      # HashLink's own packaging: hl.exe loads hlboot.dat from its directory
      # when started without arguments, so the copy gets the game's name
      # and the runtime DLL and hdlls sit next to it. Needs HASHLINK_DIR.
      : "${HASHLINK_DIR:?set HASHLINK_DIR to the HashLink installation}"
      cp "$HASHLINK_DIR"/hl.exe build/hl/HeapsPlatformer.exe
      cp "$HASHLINK_DIR"/libhl.dll "$HASHLINK_DIR"/*.hdll build/hl/ 2>/dev/null || true
      cp build/hl/game.hl build/hl/hlboot.dat
    fi
    rm -rf build/hl/assets
    mkdir -p build/hl/assets/fmod
    cp -r ../EZPlatformer/assets/fmod/Desktop build/hl/assets/fmod/
    ;;
  hlc)
    # HL/C: the generated C compiled against an installed HashLink (libhl
    # plus its hdlls, Homebrew's on macOS) into a real executable, for
    # platforms without a HashLink VM. hlaxe_fmod.hdll comes from build-hdll
    # and must match the installed HashLink's architecture (see
    # HAXEFMOD_HDLL_ARCH).
    HL_PREFIX="${HASHLINK_PREFIX:-$(brew --prefix 2>/dev/null || echo /usr/local)}"
    rm -rf build/hlc build/hl
    mkdir -p build/hlc build/hl
    # The hxml minus its output line, redirected to C
    haxe $(grep -v '^#' build-hl.hxml | grep -v '^-hl ') "$@" -hl build/hlc/main.c
    LIBS=""
    for lib in $(python3 -c "import json; print(' '.join(json.load(open('build/hlc/hlc.json'))['libs']))"); do
      case "$lib" in
        std) ;;
        hlaxe_fmod) LIBS="$LIBS .haxefmod/hlaxe_fmod.hdll" ;;
        *) LIBS="$LIBS $HL_PREFIX/lib/$lib.hdll" ;;
      esac
    done
    # libuv is linked directly: the generated C calls its functions by name
    # for Heaps' networking natives
    clang -O2 -std=gnu11 -w -o build/hl/game build/hlc/main.c -Ibuild/hlc -I"$HL_PREFIX/include" \
      -L"$HL_PREFIX/lib" -lhl -luv $LIBS -Wl,-rpath,@executable_path -Wl,-rpath,"$HL_PREFIX/lib"
    haxelib run haxefmod stage mac hl build/hl
    rm -rf build/hl/assets
    mkdir -p build/hl/assets/fmod
    cp -r ../EZPlatformer/assets/fmod/Desktop build/hl/assets/fmod/
    ;;
  js)
    haxe build-js.hxml "$@"
    haxelib run haxefmod stage html5 html5 build/html5/lib
    rm -rf build/html5/assets
    mkdir -p build/html5/assets/fmod
    cp -r ../EZPlatformer/assets/fmod/Desktop build/html5/assets/fmod/
    cp index.html build/html5/index.html
    ;;
  *)
    echo "usage: $0 hl|hlc|js [haxe args]"; exit 2 ;;
esac
