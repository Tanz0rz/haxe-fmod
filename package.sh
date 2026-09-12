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

# zip -r packages whatever is on disk. A dirty, untracked, or gitignored
# file inside a packaged directory would ship to lib.haxe.org exactly as it
# sits in the working tree. Refuse to package anything git does not know
# about, allowing only the patterns the zip itself excludes below.
if command -v git > /dev/null && git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  dirty=$(git status --porcelain --ignored -- haxefmod native templates fmod-scripts fmod_expected_version include.xml kfile.js haxelib.json README.md MIGRATION.md CHANGELOG.md LIMITATIONS.md LICENSE | grep -vE '\.DS_Store$|/\.haxefmod/|\.obj$' || true)
  if [ -n "$dirty" ]; then
    echo "ERROR: packaged paths have uncommitted or untracked changes:"
    echo "$dirty"
    echo "Commit or remove them before packaging."
    exit 1
  fi
fi

# The version being packaged must have its CHANGELOG section written
version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' haxelib.json | grep -o '[0-9][^"]*')
if [ -z "$version" ]; then
  echo "ERROR: could not read the version from haxelib.json"
  exit 1
fi
heading=$(grep -m1 "^## $version" CHANGELOG.md || true)
if [ -z "$heading" ]; then
  echo "ERROR: CHANGELOG.md has no '## $version' section for haxelib.json version $version"
  exit 1
fi

# A tag run packages a release, so its changelog section must be final.
# Set RELEASE=1 to get the same gate outside CI.
case "${GITHUB_REF:-}" in
  refs/tags/*) release=1 ;;
  *) release="${RELEASE:-}" ;;
esac
if [ -n "$release" ]; then
  case "$heading" in
    *"(unreleased)"*)
      echo "ERROR: CHANGELOG.md still marks $version as unreleased:"
      echo "  $heading"
      echo "Drop the (unreleased) marker before you tag."
      exit 1
      ;;
  esac
fi

# A release ships no hdll behind the tree. A branch build warns, since a
# shim change lands before update-hdlls can rebuild the hdlls.
abi=$(grep -m1 '^# abi-version:' native/manifest/studio_api.txt | grep -o '[0-9][0-9]*' | head -1 || true)
src=$(python3 ci/hlaxe-src-hash.py)
for platform in Linux64 Mac64 Windows64; do
  hdll="templates/bin/hl/$platform/hlaxe_fmod.hdll"
  if ! python3 - "$hdll" "$abi" "$src" <<'PY'
import re, sys
data = open(sys.argv[1], "rb").read()
abi = re.search(rb"hlaxe_fmod_abi=([0-9]+)", data)
src = re.search(rb"hlaxe_fmod_src=([0-9a-f]+)", data)
sys.exit(0 if abi and src and abi.group(1).decode() == sys.argv[2] and src.group(1).decode() == sys.argv[3] else 1)
PY
  then
    if [ -n "$release" ]; then
      echo "ERROR: $hdll is behind the tree (the tree is at ABI $abi, source $src)"
      echo "Wait for the update-hdlls auto-commit and package that tip."
      exit 1
    fi
    echo "WARNING: $hdll is behind the tree (the tree is at ABI $abi, source $src)"
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
  kfile.js \
  haxelib.json \
  README.md \
  MIGRATION.md \
  CHANGELOG.md \
  LIMITATIONS.md \
  LICENSE \
  -x "*.DS_Store" -x "*/.haxefmod/*" -x "*.obj"

echo ""
echo "Created haxefmod.zip"
echo "Submit with: haxelib submit haxefmod.zip"
