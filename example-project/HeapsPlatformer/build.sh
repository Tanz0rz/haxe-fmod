#!/bin/bash
# Builds the Heaps example for one target and lays out a runnable directory.
# Usage: ./build.sh hl|js [-D audio_test ...]
# hl: build/hl/game.hl plus the FMOD runtime and run.sh, run with build/hl/run.sh
# js: build/html5/ served as a static site, open index.html?test=<state> for a test state
set -e
cd "$(dirname "$0")"
TARGET="$1"; shift
case "$TARGET" in
  hl)
    haxe build-hl.hxml "$@"
    haxelib run haxefmod stage linux hl build/hl
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
    echo "usage: $0 hl|js [haxe args]"; exit 2 ;;
esac
