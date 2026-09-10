#!/usr/bin/env bash
# Atomic release swap on the docs host. docs.yml copies this file next to the
# releases and runs it over SSH after rsync. The docroot /var/www/tanz0rz is
# a symlink to one release directory, and the site lives under haxe-fmod/
# inside it. Caddy resolves the symlink on every request, so a swap needs no
# reload.
set -euo pipefail

RELEASE_DIR="${1:?usage: docs-release-swap.sh <release-dir>}"
LIVE_LINK=/var/www/tanz0rz
RELEASES_DIR=/var/www/releases

fail() { echo "release-swap: FAIL: $*" >&2; exit 1; }

# Sanity checks while the release is unreachable. A bad build reads as
# a failed deploy and never as a broken site.
[ -d "$RELEASE_DIR" ] || fail "release dir missing: $RELEASE_DIR"
for page in index.html 404.html getting-started/index.html api/index.html; do
  [ -s "$RELEASE_DIR/haxe-fmod/$page" ] || fail "page missing: haxe-fmod/$page"
done
grep -q "data-website-id" "$RELEASE_DIR/haxe-fmod/index.html" || fail "analytics tags missing from index.html"
grep -q "data-website-id" "$RELEASE_DIR/haxe-fmod/api/index.html" || fail "analytics tags missing from the API reference"

# The swap is one rename.
ln -sfn "$RELEASE_DIR" "${LIVE_LINK}.new"
mv -T "${LIVE_LINK}.new" "$LIVE_LINK"
[ -s "$LIVE_LINK/haxe-fmod/index.html" ] || fail "post-swap: index.html unreadable through the symlink"
echo "release-swap: live -> $RELEASE_DIR"

# Keep the last three releases and never the live one.
live_target=$(readlink -f "$LIVE_LINK")
# An empty releases directory must not abort the script under pipefail, so
# the list comes from a nullglob array instead of a bare ls.
shopt -s nullglob
releases=("$RELEASES_DIR"/*/)
shopt -u nullglob
if [ "${#releases[@]}" -gt 3 ]; then
  while IFS= read -r old; do
    old_real=$(readlink -f "$old")
    if [ "$old_real" != "$live_target" ]; then
      rm -rf "$old_real"
      echo "release-swap: pruned $old_real"
    fi
  done < <(ls -1dt -- "${releases[@]}" | tail -n +4)
fi
echo "release-swap: OK"
