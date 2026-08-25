#!/bin/bash
# Packages haxefmod for haxelib submission.
# Usage: ./package.sh
# Output: haxefmod.zip (ready for `haxelib submit haxefmod.zip`)

set -e

# Paths below are relative to the repo root, wherever the script is run from
cd "$(dirname "$0")"

# The pre-built hdlls ship in the package. Refuse to build a zip without them.
for platform in Linux64 Mac64 Windows64; do
  hdll="templates/bin/hl/$platform/hlaxe_fmod.hdll"
  if [ ! -f "$hdll" ]; then
    echo "ERROR: missing $hdll - the package would break HashLink builds"
    exit 1
  fi
done

rm -f haxefmod.zip

zip -r haxefmod.zip \
  haxefmod/ \
  native/ \
  templates/ \
  fmod-scripts/ \
  fmod_expected_version \
  include.xml \
  haxelib.json \
  README.md \
  MIGRATION.md \
  CHANGELOG.md \
  LICENSE \
  -x "*.DS_Store" -x "*/.haxefmod/*" -x "*.obj"

echo ""
echo "Created haxefmod.zip"
echo "Submit with: haxelib submit haxefmod.zip"
