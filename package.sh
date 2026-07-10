#!/bin/bash
# Packages haxefmod for haxelib submission.
# Usage: ./package.sh
# Output: haxefmod.zip (ready for `haxelib submit haxefmod.zip`)

set -e

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
  LICENSE

echo ""
echo "Created haxefmod.zip"
echo "Submit with: haxelib submit haxefmod.zip"
