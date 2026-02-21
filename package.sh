#!/bin/bash
# Packages haxefmod for haxelib submission.
# Usage: ./package.sh
# Output: haxefmod.zip (ready for `haxelib submit haxefmod.zip`)

set -e

rm -f haxefmod.zip

zip -r haxefmod.zip . \
  -x ".git/*" \
  -x ".github/*" \
  -x "ci/*" \
  -x "example-project/*" \
  -x "haxefmod.zip" \
  -x "package.sh"

echo ""
echo "Created haxefmod.zip"
echo "Submit with: haxelib submit haxefmod.zip"
