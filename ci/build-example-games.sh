#!/bin/bash
# Builds the three example games for the browser into <out>/haxeflixel,
# <out>/heaps and <out>/kha. These are the playable games (the playable
# define). Needs FMOD_SDK_WEB, KHA pointing at a Kha checkout, and haxefmod
# reachable through haxelib (haxelib dev haxefmod <checkout>).
# Usage: bash ci/build-example-games.sh <out dir>
set -euo pipefail
OUT="${1:?usage: build-example-games.sh <out dir>}"
: "${FMOD_SDK_WEB:?set FMOD_SDK_WEB to the HTML5 FMOD Engine directory}"
: "${KHA:?set KHA to the Kha checkout}"
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
rm -rf "$OUT/haxeflixel" "$OUT/heaps" "$OUT/kha"

# lime always writes to export/html5/bin, so clear it of any older build
echo "== HaxeFlixel"
rm -rf example-project/EZPlatformer/export/html5
(cd example-project/EZPlatformer && haxelib run lime build html5 -release -Dplayable)
cp -r example-project/EZPlatformer/export/html5/bin "$OUT/haxeflixel"

echo "== Heaps"
BUILD_ROOT="$WORK/heaps" example-project/HeapsPlatformer/build.sh js -D playable
cp -r "$WORK/heaps/html5" "$OUT/heaps"

echo "== Kha"
KHA_PLAYABLE=1 BUILD_ROOT="$WORK/kha" example-project/KhaPlatformer/build.sh html5
cp -r "$WORK/kha/html5" "$OUT/kha"

# Each page's title is the game's name, the one the docs site shows
for pair in haxeflixel:EZPlatformer heaps:HeapsPlatformer kha:KhaPlatformer; do
  game=${pair%%:*}
  grep -q "<title>${pair#*:}</title>" "$OUT/$game/index.html" || { echo "FAIL: $game/index.html is not titled ${pair#*:}"; exit 1; }
done

for game in haxeflixel heaps kha; do
  for f in index.html lib/fmodstudio.js lib/fmodstudio.wasm lib/jaxe.js; do
    [ -s "$OUT/$game/$f" ] || { echo "FAIL: $game is missing $f"; exit 1; }
  done
done
echo "build-example-games: OK"
